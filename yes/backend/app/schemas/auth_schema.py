"""
auth_schema.py

Pydantic schemas for user registration, login, and JWT tokens.
"""

from typing import Optional
from pydantic import BaseModel, EmailStr, Field


class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    full_name: str
    phone_number: Optional[str] = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    full_name: str


class UserResponse(BaseModel):
    user_id: str
    email: str
    full_name: str
    phone_number: Optional[str] = None
    created_at: str
