"""Durable inbox reminders; running backend required, no mobile push provider."""
from datetime import timedelta
from sqlalchemy import select
from .db import SessionLocal
from .models import User,Report,Notification,DailyPlan,PlanTask,PlanAcknowledgment,Task,now
import os

def run_reminders():
    local=now()+timedelta(hours=6)
    days={int(x) for x in os.getenv("DS_WORKDAYS","0,1,2,3,5,6").split(",")}
    if local.weekday() not in days:return
    with SessionLocal() as db:
        def notify(user,title,body,key,route):
            if not db.scalar(select(Notification.id).where(Notification.dedupe_key==key)):
                db.add(Notification(user_id=user.id,title=title,body=body,dedupe_key=key,route=route))
        for user in db.scalars(select(User).where(User.active.is_(True))):
            if user.roles!=["finance"] and 17<=local.hour<21 and not db.scalar(select(Report.id).where(Report.author_id==user.id,Report.report_date==local.date())):
                notify(user,"Your daily update is due","Share what moved forward and where you need help.",f"report-{local.date()}-{user.id}","/reports")
            if local.hour==9:
                notify(user,"Time for the daily meeting","Review today's responsibilities and open blockers.",f"meeting-{local.date()}-{user.id}","/today")
        if 20<=local.hour<21:
            tomorrow=local.date()+timedelta(days=1)
            seen=set()
            for plan in db.scalars(select(DailyPlan).where(DailyPlan.plan_date==tomorrow).order_by(DailyPlan.revision.desc())):
                if plan.project_id in seen:continue
                seen.add(plan.project_id)
                ids=list(db.scalars(select(PlanTask.task_id).where(PlanTask.plan_id==plan.id)))
                for uid in set(db.scalars(select(Task.assignee_id).where(Task.id.in_(ids)))):
                    if not db.get(PlanAcknowledgment,(plan.id,uid)):
                        user=db.get(User,uid)
                        if user and user.active:notify(user,"Have a look at tomorrow's plan","Your team is waiting for your acknowledgment.",f"plan-reminder-{plan.id}-{uid}","/planning")
        db.commit()

