from contextlib import asynccontextmanager
from datetime import date, timedelta
from decimal import Decimal
from typing import Literal
from collections import defaultdict, deque
import os, time, asyncio, logging, re
from fastapi import FastAPI, Depends, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, ConfigDict, field_validator
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from .db import get_db, DEV_MODE, DATABASE_URL
from .models import *
from .security import *

ORIGINS=os.getenv("DS_ORIGINS","http://localhost:5173,http://127.0.0.1:5173,http://localhost:8000,http://127.0.0.1:8000").split(",")
@asynccontextmanager
async def lifespan(app):
    from .seed import seed_database
    seed_database()
    async def reminders():
        from .reminders import run_reminders
        while True:
            try: await asyncio.to_thread(run_reminders)
            except Exception: logging.getLogger(__name__).exception("Reminder cycle failed")
            await asyncio.sleep(60)
    worker=asyncio.create_task(reminders())
    try: yield
    finally:
        worker.cancel()
        try: await worker
        except asyncio.CancelledError: pass
app=FastAPI(title="Digital Source",version="0.1.0",lifespan=lifespan)
app.add_middleware(CORSMiddleware,allow_origins=ORIGINS,allow_credentials=True,allow_methods=["GET","POST","PATCH"],allow_headers=["Authorization","Content-Type"])
@app.middleware("http")
async def origin_guard(request,call_next):
    if request.method in ("POST","PATCH","DELETE","PUT") and request.headers.get("origin") and request.headers["origin"] not in ORIGINS:
        return Response("Untrusted origin",status_code=403)
    response=await call_next(request)
    response.headers["X-Content-Type-Options"]="nosniff"
    response.headers["Cache-Control"]="no-store"
    response.headers["Referrer-Policy"]="no-referrer"
    return response

def audit(db,user,action,kind,entity_id,details=None):
    db.add(AuditEvent(actor_id=user.id,action=action,entity_type=kind,entity_id=entity_id,details=details or {}))
def person(u): return {k:getattr(u,k) for k in ("id","employee_id","name","email","roles","title","department","avatar","active")}
def task_json(t): return {k:(getattr(t,k).isoformat() if isinstance(getattr(t,k),date) else getattr(t,k)) for k in ("id","project_id","title","assignee_id","status","due_date","priority","blocker","review_note","version")}
def project_json(db,p):
    tasks=list(db.scalars(select(Task).where(Task.project_id==p.id,Task.status!="cancelled")))
    return {"id":p.id,"name":p.name,"client":p.client,"site":p.site,"phase":p.phase,"due_date":p.due_date.isoformat(),"image":p.image,
            "member_ids":list(db.scalars(select(ProjectMember.user_id).where(ProjectMember.project_id==p.id))),
            "lead_id":db.scalar(select(ProjectMember.user_id).where(ProjectMember.project_id==p.id,ProjectMember.project_role=="lead")),
            "membership_roles":{m.user_id:m.project_role for m in db.scalars(select(ProjectMember).where(ProjectMember.project_id==p.id))},
            "progress":round(sum(t.status=="done" for t in tasks)/len(tasks)*100) if tasks else 0,
            "task_count":len(tasks),"completed_count":sum(t.status=="done" for t in tasks),"blocked_count":sum(t.status=="blocked" for t in tasks)}
def material_json(m):
    return {"id":m.id,"project_id":m.project_id,"supplier_id":m.supplier_id,"owner_id":m.owner_id,"item":m.item,"unit":m.unit,"quantity":str(m.quantity),"received":str(m.received),"due_date":m.due_date.isoformat(),"status":m.status}
def money_json(m):
    return {"id":m.id,"project_id":m.project_id,"kind":m.kind,"amount":format(m.amount,".2f"),"payer":m.payer,"payee":m.payee,"purpose":m.purpose,"entry_date":m.entry_date.isoformat(),"method":m.method,"status":m.status,"created_by":m.created_by}
class Input(BaseModel):
    model_config=ConfigDict(str_strip_whitespace=True,extra="forbid")
class Login(Input):
    model_config=ConfigDict(str_strip_whitespace=False,extra="forbid")
    @field_validator("email")
    @classmethod
    def normalize_email(cls,value):return value.strip().lower()
    email:str=Field(min_length=3,max_length=254)
    password:str=Field(min_length=1,max_length=256)
attempts=defaultdict(deque)
@app.post("/api/v1/auth/login")
def login(data:Login,request:Request,response:Response,db=Depends(get_db)):
    key=(request.client.host if request.client else "local",data.email.lower())
    queue=attempts[key]
    while queue and queue[0]<time.monotonic()-300: queue.popleft()
    if len(queue)>=10: raise HTTPException(429,"Too many attempts. Try again in five minutes.")
    queue.append(time.monotonic())
    user=db.scalar(select(User).where(User.email==data.email.lower(),User.active.is_(True)))
    if not user or not verify(data.password,user.password_hash): raise HTTPException(401,"Email or password is incorrect.")
    attempts.pop(key,None)
    raw=create_session(db,user)
    response.set_cookie("ds_session",raw,max_age=43200,httponly=True,samesite="strict",secure=not DEV_MODE,path="/")
    return {"token":raw,"user":person(user),"landing_route":home_route(user)}
# Explicit local enrollment gate requested by the user; never returned by the API.
MANAGER_SIGNUP_CODE="1234"
class Signup(Input):
    model_config=ConfigDict(str_strip_whitespace=False,extra="forbid")
    name:str=Field(min_length=2,max_length=120)
    email:str=Field(min_length=3,max_length=254)
    password:str=Field(min_length=12,max_length=128)
    role:Literal["manager","member","finance"]="member"
    manager_code:str=Field(default="",max_length=32)
    title:str=Field(default="Team member",max_length=100)
    department:str=Field(default="General",max_length=80)
    @field_validator("email")
    @classmethod
    def normalize_email(cls,value):
        value=value.strip().lower()
        if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+",value):raise ValueError("Enter a valid email address.")
        return value
    @field_validator("name","title","department")
    @classmethod
    def normalize_profile(cls,value):
        value=value.strip()
        if not value:raise ValueError("This field cannot be blank.")
        return value
    @field_validator("name")
    @classmethod
    def validate_name(cls,value):
        if len(value)<2:raise ValueError("Enter your full name.")
        return value
    @field_validator("password")
    @classmethod
    def validate_password(cls,value):
        if len(value.strip())<12:raise ValueError("Use at least 12 non-padding characters.")
        return value

def require_local_registration():
    if not DEV_MODE or not DATABASE_URL.startswith("sqlite"):
        raise HTTPException(403,"Account setup is enabled for the local SQLite workspace.")
@app.get("/api/v1/auth/registration")
def registration_info():
    require_local_registration()
    return {"roles":["manager","member","finance"],"manager_code_required":True,"database":"sqlite"}
signup_attempts=defaultdict(deque)
@app.post("/api/v1/auth/signup",status_code=201)
def signup(data:Signup,request:Request,response:Response,db=Depends(get_db)):
    require_local_registration()
    host=request.client.host if request.client else "local"
    queue=signup_attempts[host]
    while queue and queue[0]<time.monotonic()-300:queue.popleft()
    if len(queue)>=10:raise HTTPException(429,"Too many account attempts. Try again in five minutes.")
    queue.append(time.monotonic())
    if data.role=="manager" and not secrets.compare_digest(data.manager_code.encode("utf-8"),MANAGER_SIGNUP_CODE.encode("ascii")):
        raise HTTPException(403,"The manager access code is incorrect.")
    if db.scalar(select(User.id).where(User.email==data.email)):
        raise HTTPException(409,"An account with this email already exists. Sign in instead.")
    user=User(employee_id="DS-"+uid().replace("-","")[:8].upper(),name=data.name,email=data.email,
        password_hash=hash_password(data.password),roles=[data.role],title=data.title,department=data.department,avatar=None,active=True)
    raw=secrets.token_urlsafe(48)
    try:
        db.add(user);db.flush()
        db.add(SessionToken(token_hash=digest(raw),user_id=user.id,expires_at=now()+timedelta(hours=12)))
        audit(db,user,"account.registered","user",user.id,{"role":data.role})
        db.add(Notification(user_id=user.id,title="Welcome to Digital Source",body="Your "+data.role+" workspace is ready.",route=home_route(user)))
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409,"An account with this email already exists. Sign in instead.")
    response.set_cookie("ds_session",raw,max_age=43200,httponly=True,samesite="strict",secure=False,path="/")
    return {"token":raw,"user":person(user),"landing_route":home_route(user)}


@app.get("/api/v1/auth/me")
def me(user=Depends(current_user)): return person(user)
@app.post("/api/v1/auth/logout")
def logout(request:Request,response:Response,user=Depends(current_user),db=Depends(get_db)):
    request.state.session.revoked_at=now()
    db.merge(request.state.session)
    db.commit()
    response.delete_cookie("ds_session",path="/")
    return {"ok":True}
@app.get("/api/v1/health")
def health(): return {"status":"ok","mode":"local-development","database":"sqlite" if DATABASE_URL.startswith("sqlite") else "postgresql"}
@app.get("/api/v1/workspace")
def workspace(user=Depends(current_user),db=Depends(get_db)):
    finance=user.roles==["finance"]
    projects=[p for p in db.scalars(select(Project).order_by(Project.created_at.desc())) if can_view(db,user,p.id)]
    ids=[p.id for p in projects]
    tasks=[] if finance else list(db.scalars(select(Task).where(Task.project_id.in_(ids)).order_by(Task.due_date,Task.created_at)))
    reports=[] if finance else list(db.scalars(select(Report).where(True if user.roles==["manager"] else Report.author_id==user.id).order_by(Report.report_date.desc())))
    notifications=db.scalars(select(Notification).where(Notification.user_id==user.id).order_by(Notification.created_at.desc()))
    return {"user":person(user),"landing_route":home_route(user),
        "people":[person(u) for u in db.scalars(select(User).where(User.active.is_(True)).order_by(User.employee_id))],
        "projects":[project_json(db,p) for p in projects],"tasks":[task_json(t) for t in tasks],
        "materials":[] if finance else [material_json(m) for m in db.scalars(select(Material).where(Material.project_id.in_(ids)))],
        "suppliers":[] if finance else [{"id":s.id,"name":s.name,"category":s.category} for s in db.scalars(select(Supplier))],
        "money":[money_json(m) for m in db.scalars(select(MoneyEntry).order_by(MoneyEntry.entry_date.desc()))] if finance else [],
        "reports":[{"id":r.id,"author_id":r.author_id,"report_date":r.report_date.isoformat(),"completed":r.completed,"remaining":r.remaining,"help_needed":r.help_needed} for r in reports],
        "notifications":[{"id":n.id,"title":n.title,"body":n.body,"route":n.route,"read":n.read_at is not None,"created_at":n.created_at.isoformat()} for n in notifications],
        "plans":[] if finance else plans_for(db,user,ids),"development_mode":True}

class ProjectInput(Input):
    name:str=Field(min_length=2,max_length=160)
    client:str=Field(min_length=2,max_length=120)
    site:str=Field(min_length=2,max_length=200)
    due_date:date
    member_ids:list[str]=Field(min_length=1,max_length=40)
@app.post("/api/v1/projects",status_code=201)
def create_project(data:ProjectInput,user=Depends(current_user),db=Depends(get_db)):
    require_role(user,"manager")
    if data.due_date<(now()+timedelta(hours=6)).date(): raise HTTPException(422,"Choose today or a future deadline.")
    member_ids=set(data.member_ids)|{user.id}
    members=list(db.scalars(select(User).where(User.id.in_(member_ids),User.active.is_(True))))
    if len(members)!=len(member_ids): raise HTTPException(422,"One selected employee is no longer available.")
    p=Project(name=data.name,client=data.client,site=data.site,due_date=data.due_date,created_by=user.id,image="assets/images/retail.jpg")
    db.add(p); db.flush()
    for member in members:
        db.add(ProjectMember(project_id=p.id,user_id=member.id,project_role="manager" if member.id==user.id else "member"))
        if member.id!=user.id: db.add(Notification(user_id=member.id,title="You joined "+p.name,body="Open the project to see your team and next steps.",route="/projects/"+p.id))
    audit(db,user,"project.created","project",p.id,{"members":list(member_ids)})
    db.commit()
    return project_json(db,p)

class LeadInput(Input):
    user_id:str|None=None
@app.patch("/api/v1/projects/{project_id}/lead")
def set_project_lead(project_id:str,data:LeadInput,user=Depends(current_user),db=Depends(get_db)):
    require_role(user,"manager")
    project=db.get(Project,project_id)
    if not project:raise HTTPException(404,"Project not found.")
    if data.user_id:
        target=db.get(User,data.user_id)
        if not target or not target.active or target.roles!=["member"] or not db.get(ProjectMember,(project_id,data.user_id)):
            raise HTTPException(422,"Choose an active team member already assigned to this project.")
    # Serialize lead replacement; the partial unique index also enforces the invariant.
    db.execute(update(Project).where(Project.id==project_id).values(phase=Project.phase))
    previous=db.scalar(select(ProjectMember).where(ProjectMember.project_id==project_id,ProjectMember.project_role=="lead"))
    previous_id=previous.user_id if previous else None
    if previous_id==data.user_id:
        db.rollback()
        return project_json(db,project)
    db.execute(update(ProjectMember).where(ProjectMember.project_id==project_id,ProjectMember.project_role=="lead").values(project_role="member"))
    if data.user_id:
        db.execute(update(ProjectMember).where(ProjectMember.project_id==project_id,ProjectMember.user_id==data.user_id).values(project_role="lead"))
    audit(db,user,"project.lead_changed","project",project_id,{"previous_id":previous_id,"lead_id":data.user_id})
    if data.user_id:db.add(Notification(user_id=data.user_id,title="You are the project team lead",body=project.name,route="/projects/"+project_id))
    if previous_id:db.add(Notification(user_id=previous_id,title="Project lead assignment updated",body="Your team lead responsibility for "+project.name+" has ended.",route="/projects/"+project_id))
    db.commit()
    return project_json(db,project)


class TaskInput(Input):
    project_id:str
    title:str=Field(min_length=2,max_length=200)
    assignee_id:str
    due_date:date
    priority:str="normal"
@app.post("/api/v1/tasks",status_code=201)
def create_task(data:TaskInput,user=Depends(current_user),db=Depends(get_db)):
    require_project(db,user,data.project_id,True)
    if not db.get(ProjectMember,(data.project_id,data.assignee_id)): raise HTTPException(422,"Assignee must belong to this project.")
    assignee=db.get(User,data.assignee_id)
    if not assignee or not assignee.active or assignee.roles==["finance"]:raise HTTPException(422,"Operational tasks require a manager or team member.")
    if data.priority not in ("normal","high"): raise HTTPException(422,"Invalid priority.")
    t=Task(**data.model_dump()); db.add(t); db.flush()
    audit(db,user,"task.created","task",t.id)
    db.add(Notification(user_id=t.assignee_id,title="New task assigned",body=t.title,route="/projects/"+t.project_id))
    db.commit(); return task_json(t)
class TaskUpdate(Input):
    status:str
    version:int=Field(ge=1)
    note:str=Field(default="",max_length=2000)
@app.patch("/api/v1/tasks/{task_id}")
def update_task(task_id:str,data:TaskUpdate,user=Depends(current_user),db=Depends(get_db)):
    require_role(user,"manager","member")
    t=db.get(Task,task_id)
    if not t: raise HTTPException(404,"Task not found.")
    require_project(db,user,t.project_id)
    membership=db.get(ProjectMember,(t.project_id,user.id))
    manager=can_review(db,user,t.project_id)
    if not manager and t.assignee_id!=user.id: raise HTTPException(403,"Only the assignee can update this task.")
    if data.version!=t.version: raise HTTPException(409,"This task changed. Refresh before trying again.")
    allowed={"todo":{"in_progress","blocked"},"in_progress":{"review","blocked"},"review":{"done","in_progress","blocked"},"blocked":{"in_progress"}}
    if data.status not in allowed.get(t.status,set()): raise HTTPException(422,"This status change is not allowed.")
    if data.status=="done" and not manager: raise HTTPException(403,"A reviewer must verify completion.")
    if (data.status=="blocked" or t.status=="blocked" or (t.status=="review" and data.status=="in_progress")) and not data.note:
        raise HTTPException(422,"Add a reason or resolution note.")
    if data.status=="in_progress":
        deps=list(db.scalars(select(TaskDependency.prerequisite_id).where(TaskDependency.task_id==t.id)))
        if any(db.get(Task,d).status!="done" for d in deps): raise HTTPException(422,"Finish prerequisite work first.")
    values={"status":data.status,"version":t.version+1}
    if data.status=="blocked": values["blocker"]=data.note
    elif t.status=="blocked": values["blocker"]=None
    if data.note: values["review_note"]=data.note
    changed=db.execute(update(Task).where(Task.id==t.id,Task.version==data.version).values(**values))
    if changed.rowcount!=1: raise HTTPException(409,"This task changed. Refresh before trying again.")
    audit(db,user,"task."+data.status,"task",t.id,{"note":data.note})
    if data.status in ("review","blocked"):
        recipients=set(db.scalars(select(ProjectMember.user_id).where(ProjectMember.project_id==t.project_id,ProjectMember.project_role.in_(["manager","lead"]))))
        recipients.update(u.id for u in db.scalars(select(User).where(User.active.is_(True))) if "manager" in u.roles)
    else: recipients={t.assignee_id}
    for recipient in recipients-{user.id}:
        db.add(Notification(user_id=recipient,title="Task update: "+data.status.replace("_"," "),body=t.title,route="/projects/"+t.project_id,dedupe_key=f"task-{t.id}-{data.version+1}-{recipient}"))
    db.commit(); db.refresh(t); return task_json(t)
class ReportInput(Input):
    completed:str=Field(min_length=2,max_length=5000)
    remaining:str=Field(default="",max_length=5000)
    help_needed:str=Field(default="",max_length=5000)
@app.post("/api/v1/reports")
def save_report(data:ReportInput,user=Depends(current_user),db=Depends(get_db)):
    require_role(user,"manager","member")
    today=(now()+timedelta(hours=6)).date()
    r=db.scalar(select(Report).where(Report.author_id==user.id,Report.report_date==today))
    if r:
        for k,v in data.model_dump().items(): setattr(r,k,v)
    else: r=Report(author_id=user.id,report_date=today,**data.model_dump()); db.add(r)
    db.flush(); audit(db,user,"report.saved","report",r.id); db.commit()
    return {"id":r.id}
@app.post("/api/v1/notifications/{notification_id}/read")
def read_notification(notification_id:str,user=Depends(current_user),db=Depends(get_db)):
    n=db.get(Notification,notification_id)
    if not n or n.user_id!=user.id: raise HTTPException(404,"Notification not found.")
    n.read_at=now(); db.commit(); return {"ok":True}
class MaterialInput(Input):
    project_id:str
    item:str=Field(min_length=2,max_length=200)
    quantity:Decimal=Field(gt=0,max_digits=12,decimal_places=3)
    unit:str=Field(min_length=1,max_length=20)
    supplier_id:str|None=None
    due_date:date
@app.post("/api/v1/materials",status_code=201)
def create_material(data:MaterialInput,user=Depends(current_user),db=Depends(get_db)):
    require_project(db,user,data.project_id,True)
    if data.supplier_id and not db.get(Supplier,data.supplier_id): raise HTTPException(422,"Supplier not found.")
    m=Material(**data.model_dump(),owner_id=user.id); db.add(m); db.flush()
    audit(db,user,"material.ordered","material",m.id); db.commit(); return material_json(m)
class ReceiptInput(Input):
    quantity:Decimal=Field(gt=0,max_digits=12,decimal_places=3)
@app.post("/api/v1/materials/{material_id}/receive")
def receive(material_id:str,data:ReceiptInput,user=Depends(current_user),db=Depends(get_db)):
    m=db.get(Material,material_id)
    if not m: raise HTTPException(404,"Material request not found.")
    require_project(db,user,m.project_id,True)
    changed=db.execute(update(Material).where(Material.id==m.id,Material.received+data.quantity<=Material.quantity).values(received=Material.received+data.quantity))
    if changed.rowcount!=1: raise HTTPException(422,"Received quantity exceeds the outstanding order.")
    db.refresh(m)
    m.status="received" if m.received==m.quantity else "partially_received"
    db.add(Delivery(request_id=m.id,quantity=data.quantity,created_by=user.id))
    audit(db,user,"material.received","material",m.id,{"quantity":str(data.quantity)})
    db.commit(); return material_json(m)
class MoneyInput(Input):
    project_id:str
    kind:str
    amount:Decimal=Field(gt=0,max_digits=14,decimal_places=2)
    payer:str=Field(min_length=2,max_length=160)
    payee:str=Field(min_length=2,max_length=160)
    purpose:str=Field(min_length=2,max_length=2000)
    method:str=Field(min_length=2,max_length=20)
    idempotency_key:str=Field(min_length=8,max_length=80)
@app.post("/api/v1/money",status_code=201)
def create_money(data:MoneyInput,user=Depends(current_user),db=Depends(get_db)):
    require_role(user,"finance")
    require_project(db,user,data.project_id)
    if data.kind not in ("advance","expense","refund","client_receipt"): raise HTTPException(422,"Unsupported money record type.")
    existing=db.scalar(select(MoneyEntry).where(MoneyEntry.idempotency_key==data.idempotency_key))
    if existing:
        same=existing.created_by==user.id and all(getattr(existing,k)==v for k,v in data.model_dump().items() if k!="idempotency_key")
        if not same: raise HTTPException(409,"Submission key was already used for a different record.")
        return money_json(existing)
    m=MoneyEntry(**data.model_dump(),created_by=user.id,entry_date=(now()+timedelta(hours=6)).date())
    db.add(m)
    try: db.flush()
    except IntegrityError:
        db.rollback()
        existing=db.scalar(select(MoneyEntry).where(MoneyEntry.idempotency_key==data.idempotency_key))
        if existing and existing.created_by==user.id and all(getattr(existing,k)==v for k,v in data.model_dump().items() if k!="idempotency_key"):
            return money_json(existing)
        raise HTTPException(409,"This submission conflicts with an existing record.")
    audit(db,user,"money.recorded","money",m.id); db.commit(); return money_json(m)
@app.post("/api/v1/money/{entry_id}/approve")
def approve_money(entry_id:str,user=Depends(current_user),db=Depends(get_db)):
    require_role(user,"finance")
    m=db.get(MoneyEntry,entry_id)
    if not m: raise HTTPException(404,"Record not found.")
    require_project(db,user,m.project_id)
    if m.status!="pending": raise HTTPException(409,"Only pending entries can be approved.")
    if m.created_by==user.id: raise HTTPException(422,"Another authorized person must approve your entry.")
    changed=db.execute(update(MoneyEntry).where(MoneyEntry.id==m.id,MoneyEntry.status=="pending").values(status="approved",approved_by=user.id))
    if changed.rowcount!=1: raise HTTPException(409,"Entry was already reviewed.")
    audit(db,user,"money.approved","money",m.id); db.commit(); db.refresh(m); return money_json(m)
@app.post("/api/v1/money/{entry_id}/reverse")
def reverse_money(entry_id:str,user=Depends(current_user),db=Depends(get_db)):
    require_role(user,"finance")
    m=db.get(MoneyEntry,entry_id)
    if not m: raise HTTPException(404,"Record not found.")
    require_project(db,user,m.project_id)
    if m.status!="approved": raise HTTPException(409,"Only approved entries can be reversed.")
    changed=db.execute(update(MoneyEntry).where(MoneyEntry.id==m.id,MoneyEntry.status=="approved").values(status="reversed"))
    if changed.rowcount!=1: raise HTTPException(409,"Entry was already reversed.")
    r=MoneyEntry(project_id=m.project_id,created_by=user.id,kind="reversal",amount=m.amount,payer=m.payee,payee=m.payer,purpose="Reversal: "+m.purpose,entry_date=(now()+timedelta(hours=6)).date(),method=m.method,status="approved",approved_by=user.id,reversal_of=m.id,idempotency_key="reversal-"+m.id)
    db.add(r); audit(db,user,"money.reversed","money",m.id); db.commit()
    return {"ok":True}


def plans_for(db,user,project_ids):
    plans=list(db.scalars(select(DailyPlan).where(DailyPlan.project_id.in_(project_ids)).order_by(DailyPlan.plan_date.desc(),DailyPlan.revision.desc())))
    result=[]; seen=set()
    for p in plans:
        key=(p.project_id,p.plan_date)
        if key in seen: continue
        seen.add(key)
        task_ids=list(db.scalars(select(PlanTask.task_id).where(PlanTask.plan_id==p.id)))
        recipients=set(db.scalars(select(Task.assignee_id).where(Task.id.in_(task_ids))))
        acknowledgments=list(db.scalars(select(PlanAcknowledgment.user_id).where(PlanAcknowledgment.plan_id==p.id)))
        result.append({"id":p.id,"project_id":p.project_id,"plan_date":p.plan_date.isoformat(),"revision":p.revision,"task_ids":task_ids,"recipient_ids":list(recipients),"acknowledged_ids":acknowledgments,"status":p.status})
    return result
class PlanInput(Input):
    project_id:str
    plan_date:date
    task_ids:list[str]=Field(min_length=1,max_length=100)
@app.post("/api/v1/plans",status_code=201)
def publish_plan(data:PlanInput,user=Depends(current_user),db=Depends(get_db)):
    require_project(db,user,data.project_id,True)
    if data.plan_date<(now()+timedelta(hours=6)).date(): raise HTTPException(422,"Plan date must be today or later.")
    tasks=list(db.scalars(select(Task).where(Task.id.in_(set(data.task_ids)),Task.project_id==data.project_id,Task.status.not_in(["done","cancelled"]))))
    if len(tasks)!=len(set(data.task_ids)): raise HTTPException(422,"Choose active tasks from this project.")
    previous=db.scalar(select(DailyPlan).where(DailyPlan.project_id==data.project_id,DailyPlan.plan_date==data.plan_date).order_by(DailyPlan.revision.desc()).limit(1))
    p=DailyPlan(project_id=data.project_id,plan_date=data.plan_date,revision=previous.revision+1 if previous else 1,published_by=user.id)
    db.add(p);db.flush()
    for t in tasks: db.add(PlanTask(plan_id=p.id,task_id=t.id))
    for recipient in {t.assignee_id for t in tasks}:
        db.add(Notification(user_id=recipient,title="Your plan is ready",body=f"Review your tasks for {data.plan_date.isoformat()} and acknowledge this revision.",route="/planning",dedupe_key=f"plan-{p.id}-{recipient}"))
    audit(db,user,"plan.published","plan",p.id,{"revision":p.revision,"task_ids":data.task_ids})
    db.commit();return {"id":p.id,"revision":p.revision}
@app.post("/api/v1/plans/{plan_id}/acknowledge")
def acknowledge_plan(plan_id:str,user=Depends(current_user),db=Depends(get_db)):
    p=db.get(DailyPlan,plan_id)
    if not p: raise HTTPException(404,"Plan not found.")
    require_project(db,user,p.project_id)
    latest=db.scalar(select(DailyPlan).where(DailyPlan.project_id==p.project_id,DailyPlan.plan_date==p.plan_date).order_by(DailyPlan.revision.desc()).limit(1))
    if latest.id!=p.id: raise HTTPException(409,"A newer plan is available. Refresh first.")
    ids=list(db.scalars(select(PlanTask.task_id).where(PlanTask.plan_id==p.id)))
    if not db.scalar(select(Task.id).where(Task.id.in_(ids),Task.assignee_id==user.id).limit(1)): raise HTTPException(403,"This plan has no tasks assigned to you.")
    if not db.get(PlanAcknowledgment,(p.id,user.id)):
        db.add(PlanAcknowledgment(plan_id=p.id,user_id=user.id)); audit(db,user,"plan.acknowledged","plan",p.id); db.commit()
    return {"ok":True}


from fastapi.staticfiles import StaticFiles
from pathlib import Path
_web=Path(__file__).resolve().parents[2]/"build"/"web"
from fastapi.responses import HTMLResponse
from hashlib import sha256

@app.get("/",include_in_schema=False)
@app.get("/index.html",include_in_schema=False)
def studio_entrypoint():
    index=_web/"index.html"
    entrypoint=_web/"main.dart.js"
    if not index.exists() or not entrypoint.exists():
        raise HTTPException(503,"Build the web app before opening the workspace.")
    revision=sha256(entrypoint.read_bytes()).hexdigest()[:16]
    html=index.read_text(encoding="utf-8-sig").replace("__DS_BUILD_REVISION__",revision)
    return HTMLResponse(html,headers={"X-DigitalSource-Build":revision,"Cache-Control":"no-store, max-age=0","Pragma":"no-cache"})

if _web.exists(): app.mount("/",StaticFiles(directory=str(_web),html=True),name="web")
