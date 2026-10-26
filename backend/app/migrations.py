"""Additive local migration from legacy roles to the three-actor contract."""
from sqlalchemy import select
from .db import SessionLocal,engine
from .models import User,ProjectMember,SchemaMigration,AuditEvent

def migrate_three_roles():
    with SessionLocal() as db:
        if not db.get(SchemaMigration,"three_roles_v1"):
            users=list(db.scalars(select(User)))
            for user in users:
                old=set(user.roles or [])
                user.roles=["manager" if old & {"owner","manager"} else "finance" if "finance" in old else "member"]
            db.flush()
            users_by_id={u.id:u for u in users}
            seen_leads=set()
            for membership in db.scalars(select(ProjectMember).order_by(ProjectMember.project_id,ProjectMember.user_id)):
                user=users_by_id[membership.user_id]
                if user.roles==["manager"]:membership.project_role="manager"
                elif user.roles==["member"] and membership.project_role=="lead" and membership.project_id not in seen_leads:
                    seen_leads.add(membership.project_id)
                else:membership.project_role="member"
            db.add(SchemaMigration(revision="three_roles_v1"))
            db.add(AuditEvent(actor_id=None,action="schema.three_roles",entity_type="migration",details={"accounts_preserved":len(users)}))
            db.commit()
    for index in ProjectMember.__table__.indexes:
        if index.name=="uq_project_single_lead":index.create(engine,checkfirst=True)

