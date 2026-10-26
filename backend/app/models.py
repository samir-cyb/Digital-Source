from datetime import datetime, date, timezone
from uuid import uuid4
from sqlalchemy import String, Text, Boolean, Integer, Date, DateTime, Numeric, JSON, ForeignKey, UniqueConstraint, CheckConstraint, Index
from sqlalchemy.orm import Mapped, mapped_column
from .db import Base

def uid(): return str(uuid4())
def now(): return datetime.now(timezone.utc).replace(tzinfo=None)

class User(Base):
    __tablename__="users"
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    employee_id: Mapped[str]=mapped_column(String(24),unique=True)
    name: Mapped[str]=mapped_column(String(120))
    email: Mapped[str]=mapped_column(String(254),unique=True)
    password_hash: Mapped[str]=mapped_column(Text)
    roles: Mapped[list]=mapped_column(JSON,default=list)
    title: Mapped[str]=mapped_column(String(100))
    department: Mapped[str]=mapped_column(String(80))
    avatar: Mapped[str|None]=mapped_column(String(200))
    phone: Mapped[str|None]=mapped_column(String(40))
    active: Mapped[bool]=mapped_column(Boolean,default=True)
    created_at: Mapped[datetime]=mapped_column(DateTime,default=now)

class SessionToken(Base):
    __tablename__="sessions"
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    token_hash: Mapped[str]=mapped_column(String(64),unique=True)
    user_id: Mapped[str]=mapped_column(ForeignKey("users.id"),index=True)
    expires_at: Mapped[datetime]=mapped_column(DateTime,index=True)
    revoked_at: Mapped[datetime|None]=mapped_column(DateTime)
    created_at: Mapped[datetime]=mapped_column(DateTime,default=now)

class Project(Base):
    __tablename__="projects"
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    name: Mapped[str]=mapped_column(String(160))
    client: Mapped[str]=mapped_column(String(120))
    site: Mapped[str]=mapped_column(String(200))
    phase: Mapped[str]=mapped_column(String(30),default="Design")
    due_date: Mapped[date]=mapped_column(Date)
    created_by: Mapped[str]=mapped_column(ForeignKey("users.id"))
    image: Mapped[str|None]=mapped_column(String(200))
    created_at: Mapped[datetime]=mapped_column(DateTime,default=now)

class ProjectMember(Base):
    __tablename__="project_members"
    project_id: Mapped[str]=mapped_column(ForeignKey("projects.id"),primary_key=True)
    user_id: Mapped[str]=mapped_column(ForeignKey("users.id"),primary_key=True,index=True)
    project_role: Mapped[str]=mapped_column(String(20),default="member")

class Task(Base):
    __tablename__="tasks"
    __table_args__=(CheckConstraint("status IN ('todo','in_progress','blocked','review','done','cancelled')"),Index("ix_tasks_project_status","project_id","status"),Index("ix_tasks_assignee_due","assignee_id","due_date"))
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    project_id: Mapped[str]=mapped_column(ForeignKey("projects.id"))
    title: Mapped[str]=mapped_column(String(200))
    assignee_id: Mapped[str]=mapped_column(ForeignKey("users.id"))
    status: Mapped[str]=mapped_column(String(20),default="todo")
    due_date: Mapped[date]=mapped_column(Date)
    priority: Mapped[str]=mapped_column(String(12),default="normal")
    blocker: Mapped[str|None]=mapped_column(Text)
    review_note: Mapped[str|None]=mapped_column(Text)
    version: Mapped[int]=mapped_column(Integer,default=1)
    created_at: Mapped[datetime]=mapped_column(DateTime,default=now)

class TaskDependency(Base):
    __tablename__="task_dependencies"
    task_id: Mapped[str]=mapped_column(ForeignKey("tasks.id"),primary_key=True)
    prerequisite_id: Mapped[str]=mapped_column(ForeignKey("tasks.id"),primary_key=True,index=True)

class Report(Base):
    __tablename__="reports"
    __table_args__=(UniqueConstraint("author_id","report_date"),)
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    author_id: Mapped[str]=mapped_column(ForeignKey("users.id"))
    report_date: Mapped[date]=mapped_column(Date,index=True)
    completed: Mapped[str]=mapped_column(Text)
    remaining: Mapped[str]=mapped_column(Text,default="")
    help_needed: Mapped[str]=mapped_column(Text,default="")
    created_at: Mapped[datetime]=mapped_column(DateTime,default=now)

class Supplier(Base):
    __tablename__="suppliers"
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    name: Mapped[str]=mapped_column(String(160))
    contact: Mapped[str|None]=mapped_column(String(160))
    category: Mapped[str]=mapped_column(String(80))

class Material(Base):
    __tablename__="material_requests"
    __table_args__=(CheckConstraint("quantity > 0 AND received >= 0 AND received <= quantity"),)
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    project_id: Mapped[str]=mapped_column(ForeignKey("projects.id"),index=True)
    supplier_id: Mapped[str|None]=mapped_column(ForeignKey("suppliers.id"),index=True)
    owner_id: Mapped[str]=mapped_column(ForeignKey("users.id"))
    item: Mapped[str]=mapped_column(String(200))
    unit: Mapped[str]=mapped_column(String(20))
    quantity: Mapped[float]=mapped_column(Numeric(12,3))
    received: Mapped[float]=mapped_column(Numeric(12,3),default=0)
    due_date: Mapped[date]=mapped_column(Date,index=True)
    status: Mapped[str]=mapped_column(String(20),default="ordered")

class Delivery(Base):
    __tablename__="deliveries"
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    request_id: Mapped[str]=mapped_column(ForeignKey("material_requests.id"),index=True)
    quantity: Mapped[float]=mapped_column(Numeric(12,3))
    created_by: Mapped[str]=mapped_column(ForeignKey("users.id"))
    note: Mapped[str|None]=mapped_column(Text)
    created_at: Mapped[datetime]=mapped_column(DateTime,default=now)

class MoneyEntry(Base):
    __tablename__="money_entries"
    __table_args__=(CheckConstraint("amount > 0"),Index("ix_money_project_date","project_id","entry_date"))
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    project_id: Mapped[str]=mapped_column(ForeignKey("projects.id"))
    created_by: Mapped[str]=mapped_column(ForeignKey("users.id"),index=True)
    kind: Mapped[str]=mapped_column(String(20))
    amount: Mapped[float]=mapped_column(Numeric(14,2))
    payer: Mapped[str]=mapped_column(String(160))
    payee: Mapped[str]=mapped_column(String(160))
    purpose: Mapped[str]=mapped_column(Text)
    entry_date: Mapped[date]=mapped_column(Date)
    method: Mapped[str]=mapped_column(String(20))
    status: Mapped[str]=mapped_column(String(20),default="pending")
    approved_by: Mapped[str|None]=mapped_column(ForeignKey("users.id"))
    reversal_of: Mapped[str|None]=mapped_column(ForeignKey("money_entries.id"),unique=True)
    idempotency_key: Mapped[str]=mapped_column(String(80),unique=True)
    created_at: Mapped[datetime]=mapped_column(DateTime,default=now)

class Notification(Base):
    __tablename__="notifications"
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    user_id: Mapped[str]=mapped_column(ForeignKey("users.id"),index=True)
    title: Mapped[str]=mapped_column(String(160))
    body: Mapped[str]=mapped_column(Text)
    route: Mapped[str]=mapped_column(String(200))
    read_at: Mapped[datetime|None]=mapped_column(DateTime)
    created_at: Mapped[datetime]=mapped_column(DateTime,default=now)
    dedupe_key: Mapped[str]=mapped_column(String(160),unique=True,default=uid)

class AuditEvent(Base):
    __tablename__="audit_events"
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    actor_id: Mapped[str|None]=mapped_column(ForeignKey("users.id"))
    action: Mapped[str]=mapped_column(String(80))
    entity_type: Mapped[str]=mapped_column(String(40))
    entity_id: Mapped[str|None]=mapped_column(String(36))
    details: Mapped[dict]=mapped_column(JSON,default=dict)
    created_at: Mapped[datetime]=mapped_column(DateTime,default=now)


class DailyPlan(Base):
    __tablename__="daily_plans"
    __table_args__=(UniqueConstraint("project_id","plan_date","revision"),)
    id: Mapped[str]=mapped_column(String(36),primary_key=True,default=uid)
    project_id: Mapped[str]=mapped_column(ForeignKey("projects.id"),index=True)
    plan_date: Mapped[date]=mapped_column(Date,index=True)
    revision: Mapped[int]=mapped_column(Integer,default=1)
    status: Mapped[str]=mapped_column(String(20),default="published")
    published_by: Mapped[str]=mapped_column(ForeignKey("users.id"))
    published_at: Mapped[datetime]=mapped_column(DateTime,default=now)
class PlanTask(Base):
    __tablename__="plan_tasks"
    plan_id: Mapped[str]=mapped_column(ForeignKey("daily_plans.id"),primary_key=True)
    task_id: Mapped[str]=mapped_column(ForeignKey("tasks.id"),primary_key=True)
class PlanAcknowledgment(Base):
    __tablename__="plan_acknowledgments"
    plan_id: Mapped[str]=mapped_column(ForeignKey("daily_plans.id"),primary_key=True)
    user_id: Mapped[str]=mapped_column(ForeignKey("users.id"),primary_key=True)
    acknowledged_at: Mapped[datetime]=mapped_column(DateTime,default=now)


class WorkspaceRegistration(Base):
    __tablename__="workspace_registration"
    claim_key: Mapped[str]=mapped_column(String(40),primary_key=True)
    owner_user_id: Mapped[str]=mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime]=mapped_column(DateTime,default=now)


class SchemaMigration(Base):
    __tablename__="schema_migrations"
    revision: Mapped[str]=mapped_column(String(80),primary_key=True)
    applied_at: Mapped[datetime]=mapped_column(DateTime,default=now)

Index("uq_project_single_lead",ProjectMember.project_id,unique=True,
      sqlite_where=ProjectMember.project_role=="lead",postgresql_where=ProjectMember.project_role=="lead")
