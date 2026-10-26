import os, secrets
from datetime import date, timedelta
from pathlib import Path
from decimal import Decimal
from sqlalchemy import select
from .db import Base,engine,SessionLocal,ROOT
from .models import *
from .security import hash_password

def _seed_database():
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        if db.scalar(select(User.id).limit(1)): return
        password=os.getenv("DS_BOOTSTRAP_PASSWORD")
        if not password:
            password=secrets.token_urlsafe(18)
            access=ROOT/"work"/"local-access.txt"
            access.parent.mkdir(parents=True,exist_ok=True)
            access.write_text("LOCAL DEVELOPMENT ONLY\nEmail: owner@digitalsource.local\nPassword: "+password+"\nOther sample staff use the same bootstrap password.\n",encoding="utf-8")
        hashed=hash_password(password)
        specs=[
            ("Nabil Rahman","manager","Studio director","Leadership","owner",1),
            ("Nusrat Jahan","manager","Project manager","Projects","nusrat",2),
            ("Arif Hossain","member","Interior designer","Design","arif",3),
            ("Farhana Islam","member","Site supervisor","Site operations","farhana",4),
            ("Tanvir Ahmed","member","Sourcing specialist","Procurement","tanvir",5),
            ("Mehzabin Noor","finance","Finance executive","Finance","mehzabin",6),
            ("Rafiul Karim","member","Technical designer","Design","rafiul",7)]
        users=[]
        for i,(name,role,title,dept,email,img) in enumerate(specs,1):
            u=User(employee_id=f"DS-{i:03}",name=name,email=email+"@digitalsource.local",roles=[role],title=title,department=dept,avatar=f"assets/images/person{img}.jpg",password_hash=hashed)
            db.add(u); users.append(u)
        db.flush()
        today=(now()+timedelta(hours=6)).date()
        projects=[]
        for name,client,site,phase,days,image in [
            ("Bata flagship experience","Bata","Gulshan, Dhaka","Installation",18,"retail"),
            ("A workspace that inspires","Northstar","Banani, Dhaka","Sourcing",32,"office"),
            ("The Lakeview residence","Private client","Dhanmondi, Dhaka","Design",45,"residence")]:
            p=Project(name=name,client=client,site=site,phase=phase,due_date=today+timedelta(days=days),created_by=users[0].id,image=f"assets/images/{image}.jpg")
            db.add(p); projects.append(p)
        db.flush()
        for p in projects:
            for u in users:
                db.add(ProjectMember(project_id=p.id,user_id=u.id,project_role="manager" if u==users[1] else "lead" if u==users[3] else "member"))
        rows=[
            (0,"Approve the storefront lighting layout",1,"review",0,"high",None),
            (0,"Install the glass display partitions",3,"blocked",0,"high","Waiting for supplier delivery of tempered glass."),
            (0,"Finalize the material finish board",2,"in_progress",0,"normal",None),
            (0,"Verify the final site measurements",3,"done",-2,"normal",None),
            (0,"Confirm the furniture production drawings",6,"done",-1,"normal",None),
            (0,"Complete electrical routing review",1,"done",-1,"normal",None),
            (0,"Place the timber purchase order",4,"done",-1,"normal",None),
            (0,"Inspect the showroom handover checklist",1,"todo",1,"normal",None),
            (1,"Confirm the ergonomic chair samples",4,"todo",0,"high",None),
            (1,"Review the meeting room concept",2,"review",1,"normal",None),
            (1,"Prepare the site access schedule",3,"in_progress",1,"normal",None),
            (2,"Explore the living room material palette",2,"in_progress",0,"normal",None),
            (2,"Share the revised space plan",6,"todo",1,"normal",None),
            (2,"Record the client design brief",1,"done",-1,"normal",None)]
        for pi,title,ui,status,days,priority,blocker in rows:
            db.add(Task(project_id=projects[pi].id,title=title,assignee_id=users[ui].id,status=status,due_date=today+timedelta(days=days),priority=priority,blocker=blocker))
        suppliers=[Supplier(name="Crystal Glass Works",category="Glass",contact="Dhaka"),Supplier(name="Timber & Grain",category="Wood",contact="Dhaka"),Supplier(name="Form Seating",category="Furniture",contact="Dhaka")]
        db.add_all(suppliers); db.flush()
        for pi,si,item,unit,qty,received,days in [(0,0,"12mm tempered glass","panels",12,8,0),(0,1,"Premium oak veneer","sheets",24,24,-1),(1,2,"Ergonomic task chairs","pieces",18,6,3)]:
            db.add(Material(project_id=projects[pi].id,supplier_id=suppliers[si].id,owner_id=users[4].id,item=item,unit=unit,quantity=qty,received=received,due_date=today+timedelta(days=days),status="received" if qty==received else "partially_received"))
        for kind,amount,payer,payee,purpose,status in [
            ("client_receipt","250000","Bata","Digital Source","Project mobilization payment","approved"),
            ("advance","35000","Digital Source","Tanvir Ahmed","Glass sourcing advance","approved"),
            ("expense","28000","Tanvir Ahmed","Crystal Glass Works","Tempered glass first delivery","approved"),
            ("expense","12500","Digital Source","Timber & Grain","Oak veneer delivery","pending")]:
            db.add(MoneyEntry(project_id=projects[0].id,created_by=users[5].id,kind=kind,amount=Decimal(amount),payer=payer,payee=payee,purpose=purpose,entry_date=today,method="bank",status=status,approved_by=users[0].id if status=="approved" else None,idempotency_key=uid()))
        for u in users:
            db.add(Notification(user_id=u.id,title="Your studio workspace is ready",body="Sample projects and fictional team profiles are ready to explore.",route="/projects"))
            if u==users[0]:
                db.add(Notification(user_id=u.id,title="Lighting layout needs a review",body="Bata flagship experience has a task waiting for approval.",route="/projects/"+projects[0].id))
                db.add(Notification(user_id=u.id,title="Glass delivery is holding up installation",body="The site team is waiting for four remaining glass panels.",route="/sourcing"))
        db.commit()
def seed_database():
    _seed_database()
    from .migrations import migrate_three_roles
    migrate_three_roles()

if __name__=="__main__":
    seed_database()
    print("Local development database initialized. Bootstrap access is in work/local-access.txt when generated.")

