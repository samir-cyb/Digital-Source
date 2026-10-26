import os
import tempfile
from pathlib import Path
os.environ["DATABASE_URL"] = "sqlite:///" + str(Path(tempfile.mkdtemp()) / "test.db")
os.environ["DS_BOOTSTRAP_PASSWORD"] = "Test-only-long-passphrase!"
os.environ["DS_DEV_MODE"] = "1"
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.seed import seed_database
from backend.app.db import Base, engine
import pytest

@pytest.fixture(autouse=True)
def isolated_database():
    assert str(engine.url.database).endswith("test.db")
    from backend.app.main import signup_attempts
    signup_attempts.clear()
    Base.metadata.drop_all(engine)
    seed_database()


def client_for(email="owner@digitalsource.local"):
    seed_database()
    client = TestClient(app)
    result = client.post("/api/v1/auth/login", json={"email":email,"password":"Test-only-long-passphrase!"})
    assert result.status_code == 200, result.text
    client.headers["Authorization"] = "Bearer " + result.json()["token"]
    return client

def test_requires_login_and_logout_revokes():
    client = TestClient(app)
    assert client.get("/api/v1/workspace").status_code == 401
    client = client_for()
    assert client.get("/api/v1/workspace").status_code == 200
    assert client.post("/api/v1/auth/logout").status_code == 200
    assert client.get("/api/v1/workspace").status_code == 401

def test_project_creation_persists_photo_card_members():
    client = client_for()
    people = client.get("/api/v1/workspace").json()["people"]
    response = client.post("/api/v1/projects", json={"name":"Test retail","client":"Sample client","site":"Dhaka","due_date":"2027-02-15","member_ids":[people[1]["id"],people[2]["id"]]})
    assert response.status_code == 201, response.text
    assert set(response.json()["member_ids"]) >= {people[1]["id"],people[2]["id"]}
    assert any(p["name"]=="Test retail" for p in client.get("/api/v1/workspace").json()["projects"])

def test_member_cannot_create_project_or_read_finance():
    client = client_for("arif@digitalsource.local")
    response = client.post("/api/v1/projects",json={"name":"Forbidden","client":"Client","site":"Dhaka","due_date":"2027-01-01","member_ids":[client.get("/api/v1/workspace").json()["user"]["id"]]})
    assert response.status_code == 403
    assert client.get("/api/v1/workspace").json()["money"] == []

def test_task_invalid_transition_and_optimistic_lock():
    client=client_for()
    task=next(t for t in client.get("/api/v1/workspace").json()["tasks"] if t["status"]=="todo")
    path="/api/v1/tasks/"+task["id"]
    assert client.patch(path,json={"status":"done","version":task["version"]}).status_code==422
    assert client.patch(path,json={"status":"blocked","version":task["version"],"note":""}).status_code==422
    assert client.patch(path,json={"status":"in_progress","version":task["version"]}).status_code==200
    assert client.patch(path,json={"status":"review","version":task["version"]}).status_code==409

def test_money_idempotency_and_advance_not_expense():
    client=client_for("mehzabin@digitalsource.local")
    project=client.get("/api/v1/workspace").json()["projects"][0]
    payload={"project_id":project["id"],"kind":"advance","amount":"20000.00","payer":"Owner","payee":"Buyer","purpose":"Glass advance","method":"bank","idempotency_key":"test-idempotency-unique"}
    a=client.post("/api/v1/money",json=payload)
    b=client.post("/api/v1/money",json=payload)
    assert a.status_code==201, a.text
    assert a.json()["id"]==b.json()["id"]
    assert a.json()["amount"]=="20000.00"
    assert a.json()["status"]=="pending"
    assert client.post("/api/v1/money/"+a.json()["id"]+"/approve").status_code==422
    assert client.post("/api/v1/money",json={**payload,"amount":"-2","idempotency_key":"invalid"}).status_code==422

def test_partial_delivery_cannot_exceed_order():
    client=client_for()
    item=next(m for m in client.get("/api/v1/workspace").json()["materials"] if float(m["received"])<float(m["quantity"]))
    path="/api/v1/materials/"+item["id"]+"/receive"
    assert client.post(path,json={"quantity":"99999"}).status_code==422
    assert client.post(path,json={"quantity":"1"}).status_code==200


def test_plan_revision_requires_fresh_acknowledgment():
    owner=client_for()
    data=owner.get("/api/v1/workspace").json()
    arif=next(p for p in data["people"] if p["email"]=="arif@digitalsource.local")
    task=next(t for t in data["tasks"] if t["assignee_id"]==arif["id"] and t["status"] not in ("done","cancelled"))
    payload={"project_id":task["project_id"],"plan_date":"2027-01-05","task_ids":[task["id"]]}
    first=owner.post("/api/v1/plans",json=payload)
    assert first.status_code==201,first.text
    member=client_for("arif@digitalsource.local")
    assert member.post("/api/v1/plans/"+first.json()["id"]+"/acknowledge").status_code==200
    second=owner.post("/api/v1/plans",json=payload)
    assert second.json()["revision"]==first.json()["revision"]+1
    assert member.post("/api/v1/plans/"+first.json()["id"]+"/acknowledge").status_code==409
    plan=next(p for p in member.get("/api/v1/workspace").json()["plans"] if p["id"]==second.json()["id"])
    assert plan["acknowledged_ids"]==[]

def test_daily_report_updates_without_duplicate():
    client=client_for()
    client.post("/api/v1/reports",json={"completed":"Measured site","remaining":"Drawings"})
    client.post("/api/v1/reports",json={"completed":"Measured site and prepared drawings","remaining":""})
    reports=client.get("/api/v1/workspace").json()["reports"]
    assert len(reports)==1
    assert reports[0]["completed"]=="Measured site and prepared drawings"

def test_financial_approval_is_separate_and_reversal_preserves_history():
    client,response=signup_role("finance",email="review-finance@example.com")
    assert response.status_code==201,response.text
    workspace=client.get("/api/v1/workspace").json()
    pending=next(m for m in workspace["money"] if m["status"]=="pending")
    path="/api/v1/money/"+pending["id"]
    assert client.post(path+"/approve").status_code==200
    assert client.post(path+"/approve").status_code==409
    assert client.post(path+"/reverse").status_code==200
    assert client.post(path+"/reverse").status_code==409
    entries=client.get("/api/v1/workspace").json()["money"]
    assert next(m for m in entries if m["id"]==pending["id"])["status"]=="reversed"
    assert any(m["kind"]=="reversal" for m in entries)

def test_project_data_is_hidden_from_unassigned_member():
    owner=client_for()
    data=owner.get("/api/v1/workspace").json()
    manager=next(p for p in data["people"] if "manager" in p["roles"])
    p=owner.post("/api/v1/projects",json={"name":"Private project","client":"Private client","site":"Dhaka","due_date":"2027-02-15","member_ids":[manager["id"]]}).json()
    member=client_for("arif@digitalsource.local")
    assert p["id"] not in [x["id"] for x in member.get("/api/v1/workspace").json()["projects"]]
    assert member.post("/api/v1/plans",json={"project_id":p["id"],"plan_date":"2027-01-01","task_ids":["missing"]}).status_code==404

def test_csrf_untrusted_origin_rejected():
    client=client_for()
    assert client.post("/api/v1/auth/logout",headers={"Origin":"https://untrusted.example"}).status_code==403


def test_reminder_worker_is_idempotent(monkeypatch):
    from datetime import datetime
    from backend.app import reminders
    from backend.app.db import SessionLocal
    from backend.app.models import Notification
    from sqlalchemy import select
    monkeypatch.setattr(reminders,"now",lambda:datetime(2027,1,4,11,5))
    reminders.run_reminders()
    reminders.run_reminders()
    with SessionLocal() as db:
        notes=list(db.scalars(select(Notification).where(Notification.dedupe_key.like("report-2027-01-04-%"))))
        assert len(notes)==6
        assert len({n.dedupe_key for n in notes})==6


def test_signup_creates_manager_with_code_and_persists_hashed_password():
    from backend.app.db import SessionLocal
    from backend.app.models import User
    from backend.app.security import verify
    from sqlalchemy import select
    client=TestClient(app)
    info=client.get("/api/v1/auth/registration")
    assert info.status_code==200
    assert info.json()=={"roles":["manager","member","finance"],"manager_code_required":True,"database":"sqlite"}
    payload={"name":"Studio Owner","email":"  MY.OWNER@example.com  ","password":" My new owner passphrase! ","title":"Studio director","department":"Leadership","role":"manager","manager_code":"1234"}
    response=client.post("/api/v1/auth/signup",json=payload)
    assert response.status_code==201,response.text
    assert response.json()["user"]["roles"]==["manager"]
    assert response.json()["user"]["email"]=="my.owner@example.com"
    assert client.get("/api/v1/auth/me").status_code==200
    with SessionLocal() as db:
        user=db.scalar(select(User).where(User.email=="my.owner@example.com"))
        assert user.password_hash!=payload["password"]
        assert verify(payload["password"],user.password_hash)
        assert user.employee_id.startswith("DS-")
    assert client.post("/api/v1/auth/logout").status_code==200
    assert client.post("/api/v1/auth/login",json={"email":payload["email"],"password":payload["password"]}).status_code==200

def test_signup_subsequent_account_is_member_without_project_access():
    client=TestClient(app)
    for name,email in [("Owner account","new-owner@example.com"),("Team account","new-member@example.com")]:
        response=client.post("/api/v1/auth/signup",json={"name":name,"email":email,"password":"A long test passphrase!"})
        assert response.status_code==201,response.text
    assert response.json()["user"]["roles"]==["member"]
    assert client.get("/api/v1/workspace").json()["projects"]==[]
    assert client.get("/api/v1/auth/registration").json()["manager_code_required"] is True

def test_signup_rejects_duplicate_email_and_role_injection():
    client=TestClient(app)
    payload={"name":"Example Member","email":"new@example.com","password":"A long test passphrase!"}
    assert client.post("/api/v1/auth/signup",json=payload).status_code==201
    assert client.post("/api/v1/auth/signup",json={**payload,"email":" NEW@EXAMPLE.COM "}).status_code==409
    assert client.post("/api/v1/auth/signup",json={**payload,"email":"another@example.com","roles":["owner"]}).status_code==422

def test_signup_validates_email_name_and_password():
    client=TestClient(app)
    payload={"name":"Example Member","email":"valid@example.com","password":"A long test passphrase!"}
    for changes in [{"email":"not-an-email"},{"name":" "},{"password":"short"}]:
        assert client.post("/api/v1/auth/signup",json={**payload,**changes}).status_code==422


def test_web_entrypoint_versions_scripts_and_disables_stale_html(monkeypatch,tmp_path):
    from backend.app import main
    (tmp_path/"index.html").write_text('<meta name="ds-build" content="__DS_BUILD_REVISION__"><script src="flutter_bootstrap.js?v=__DS_BUILD_REVISION__"></script>',encoding="utf-8")
    (tmp_path/"main.dart.js").write_text("old build",encoding="utf-8")
    monkeypatch.setattr(main,"_web",tmp_path)
    client=TestClient(app)
    old=client.get("/")
    assert old.status_code==200
    assert "__DS_BUILD_REVISION__" not in old.text
    assert "no-store" in old.headers["cache-control"]
    assert old.headers.get("x-digitalsource-build")
    (tmp_path/"main.dart.js").write_text("new signup build",encoding="utf-8")
    new=client.get("/index.html")
    assert new.headers["x-digitalsource-build"]!=old.headers["x-digitalsource-build"]
    assert new.headers["x-digitalsource-build"] in new.text


def signup_role(role,code=None,email=None):
    client=TestClient(app)
    payload={"name":"Role Test","email":email or role+"-signup@example.com","password":"A long role test passphrase!","role":role}
    if code is not None:payload["manager_code"]=code
    return client,client.post("/api/v1/auth/signup",json=payload)

@pytest.mark.parametrize("role,home",[("manager","/manager"),("member","/my-work"),("finance","/finance")])
def test_three_roles_have_distinct_auth_landing(role,home):
    client,response=signup_role(role,"1234" if role=="manager" else None)
    assert response.status_code==201,response.text
    assert response.json()["user"]["roles"]==[role]
    assert response.json()["landing_route"]==home
    assert client.get("/api/v1/workspace").json()["landing_route"]==home
    client.post("/api/v1/auth/logout")
    login=client.post("/api/v1/auth/login",json={"email":role+"-signup@example.com","password":"A long role test passphrase!"})
    assert login.json()["landing_route"]==home

def test_manager_signup_requires_server_checked_code():
    for code in [None,"","0000","12345","১২৩৪","🔑1234"]:
        client,response=signup_role("manager",code,email="blocked-manager@example.com")
        assert response.status_code==403,response.text
    client,response=signup_role("owner","1234")
    assert response.status_code==422
    client,response=signup_role("lead")
    assert response.status_code==422
    client,response=signup_role("finance",email="finance-allowed@example.com")
    assert response.status_code==201

def test_project_lead_is_unique_replaceable_and_project_scoped():
    manager=client_for()
    workspace=manager.get("/api/v1/workspace").json()
    arif=next(p for p in workspace["people"] if p["email"]=="arif@digitalsource.local")
    rafiul=next(p for p in workspace["people"] if p["email"]=="rafiul@digitalsource.local")
    project=manager.post("/api/v1/projects",json={"name":"Lead scope test","client":"Client","site":"Dhaka","due_date":"2027-02-15","member_ids":[arif["id"],rafiul["id"]]}).json()
    second=manager.post("/api/v1/projects",json={"name":"Second lead scope","client":"Client","site":"Dhaka","due_date":"2027-02-15","member_ids":[arif["id"]]}).json()
    endpoint="/api/v1/projects/"+project["id"]+"/lead"
    assert manager.patch(endpoint,json={"user_id":arif["id"]}).json()["lead_id"]==arif["id"]
    member=client_for("arif@digitalsource.local")
    task={"project_id":project["id"],"title":"Lead-created task","assignee_id":arif["id"],"due_date":"2027-01-01"}
    assert member.post("/api/v1/tasks",json=task).status_code==201
    assert member.post("/api/v1/tasks",json={**task,"project_id":second["id"]}).status_code==403
    assert member.patch(endpoint,json={"user_id":rafiul["id"]}).status_code==403
    replaced=manager.patch(endpoint,json={"user_id":rafiul["id"]})
    assert replaced.status_code==200,replaced.text
    assert replaced.json()["lead_id"]==rafiul["id"]
    assert member.post("/api/v1/tasks",json=task).status_code==403
    assert manager.patch(endpoint,json={"user_id":None}).json()["lead_id"] is None
    assert member.get("/api/v1/auth/me").json()["roles"]==["member"]

def test_finance_cannot_create_projects_or_modify_operational_tasks():
    client=client_for("mehzabin@digitalsource.local")
    workspace=client.get("/api/v1/workspace").json()
    assert workspace["money"]
    assert workspace["tasks"]==[]
    assert workspace["reports"]==[]
    assert workspace["materials"]==[]
    assert client.post("/api/v1/projects",json={"name":"Forbidden","client":"Client","site":"Dhaka","due_date":"2027-02-15","member_ids":[workspace["user"]["id"]]}).status_code==403
    manager=client_for()
    task=manager.get("/api/v1/workspace").json()["tasks"][0]
    assert client.patch("/api/v1/tasks/"+task["id"],json={"status":"blocked","version":task["version"],"note":"Not permitted"}).status_code==403
    assert manager.get("/api/v1/workspace").json()["money"]==[]

def test_existing_roles_migrate_without_deleting_accounts_or_projects():
    from backend.app.db import SessionLocal,engine
    from backend.app.migrations import migrate_three_roles
    from backend.app.models import User,Project,SchemaMigration
    from sqlalchemy import select
    import json
    with SessionLocal() as db:
        user=db.scalar(select(User).where(User.email=="arif@digitalsource.local"))
        user.roles=["lead"]
        marker=db.get(SchemaMigration,"three_roles_v1")
        if marker:db.delete(marker)
        db.commit()
        count=len(list(db.scalars(select(Project.id))))
        uid=user.id
    migrate_three_roles()
    with SessionLocal() as db:
        assert db.get(User,uid).roles==["member"]
        assert len(list(db.scalars(select(Project.id))))==count
        assert all(u.roles[0] in ("manager","member","finance") and len(u.roles)==1 for u in db.scalars(select(User)))


def test_database_rejects_a_second_lead_in_the_same_project():
    from backend.app.db import SessionLocal
    from backend.app.models import ProjectMember
    from sqlalchemy import select
    from sqlalchemy.exc import IntegrityError
    manager=client_for()
    workspace=manager.get("/api/v1/workspace").json()
    project=workspace["projects"][0]
    member=next(p for p in workspace["people"] if p["email"]=="arif@digitalsource.local")
    assert project["lead_id"] is not None
    with SessionLocal() as db:
        assignment=db.get(ProjectMember,(project["id"],member["id"]))
        assignment.project_role="lead"
        with pytest.raises(IntegrityError):db.commit()
        db.rollback()
        assert len(list(db.scalars(select(ProjectMember).where(ProjectMember.project_id==project["id"],ProjectMember.project_role=="lead"))))==1

