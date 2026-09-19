"""
auth.py

FastAPI authentication router for register, login, and profile.
"""

from datetime import datetime, timezone
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database.session import get_db
from app.schemas.auth_schema import UserRegister, UserLogin, TokenResponse, UserResponse
from app.models.user import UserModel
from app.core.security import get_password_hash, verify_password, create_access_token

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register_user(payload: UserRegister, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(UserModel).where(UserModel.email == payload.email))
    existing = result.scalars().first()
    if existing:
        raise HTTPException(status_code=400, detail="User with this email already exists.")

    user_id = f"usr_{uuid.uuid4().hex[:12]}"
    user = UserModel(
        user_id=user_id,
        email=payload.email,
        hashed_password=get_password_hash(payload.password),
        full_name=payload.full_name,
        phone_number=payload.phone_number
    )
    db.add(user)
    await db.flush()

    return UserResponse(
        user_id=user.user_id,
        email=user.email,
        full_name=user.full_name,
        phone_number=user.phone_number,
        created_at=user.created_at.isoformat()
    )


@router.post("/login", response_model=TokenResponse)
async def login_user(payload: UserLogin, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(UserModel).where(UserModel.email == payload.email))
    user = result.scalars().first()
    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password.")

    token = create_access_token(subject=user.user_id)
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=user.user_id,
        full_name=user.full_name
    )
