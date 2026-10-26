import hashlib,secrets
from datetime import timedelta
from argon2 import PasswordHasher
from argon2.exceptions import VerificationError,InvalidHashError
from fastapi import Depends,HTTPException,Request
from sqlalchemy import select
from .db import get_db
from .models import User,SessionToken,ProjectMember,now

hasher=PasswordHasher()
def digest(token):return hashlib.sha256(token.encode()).hexdigest()
def hash_password(password):return hasher.hash(password)
def verify(password,hashed):
    try:return hasher.verify(hashed,password)
    except (VerificationError,InvalidHashError):return False
def home_route(user):
    return {"manager":"/manager","member":"/my-work","finance":"/finance"}[user.roles[0]]
def create_session(db,user):
    raw=secrets.token_urlsafe(48)
    db.add(SessionToken(token_hash=digest(raw),user_id=user.id,expires_at=now()+timedelta(hours=12)))
    db.commit()
    return raw
def current_user(request:Request,db=Depends(get_db)):
    bearer=request.headers.get("Authorization","")
    raw=bearer[7:] if bearer.startswith("Bearer ") else request.cookies.get("ds_session","")
    if not raw:raise HTTPException(401,"Please sign in to continue.")
    token=db.scalar(select(SessionToken).where(SessionToken.token_hash==digest(raw),SessionToken.revoked_at.is_(None),SessionToken.expires_at>now()))
    user=db.get(User,token.user_id) if token else None
    if not user or not user.active:raise HTTPException(401,"Please sign in to continue.")
    if len(user.roles)!=1 or user.roles[0] not in ("manager","member","finance"):raise HTTPException(403,"Account role requires migration.")
    request.state.session=token
    return user
def require_role(user,*roles):
    if user.roles[0] not in roles:raise HTTPException(403,"Your role cannot perform this action.")
def can_view(db,user,project_id):
    return user.roles[0] in ("manager","finance") or db.get(ProjectMember,(project_id,user.id)) is not None
def can_review(db,user,project_id):
    if user.roles==["manager"]:return True
    membership=db.get(ProjectMember,(project_id,user.id))
    return user.roles==["member"] and membership is not None and membership.project_role=="lead"
def require_project(db,user,project_id,manage=False):
    if not can_view(db,user,project_id):raise HTTPException(404,"Project not found.")
    if manage and not can_review(db,user,project_id):raise HTTPException(403,"Project management permission required.")

