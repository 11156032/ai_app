"""
JWT 認證工具模組
處理密碼雜湊、JWT Token 產生與驗證
"""

import os
from datetime import datetime, timedelta, timezone
from typing import Optional

from dotenv import load_dotenv
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

load_dotenv()

# ── 設定 ──
SECRET_KEY = os.getenv("JWT_SECRET", "ai-app-super-secret-key-change-me-2026")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "10080"))  # 預設 7 天

# ── 密碼雜湊 ──
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ── Bearer Token 安全配置 ──
security = HTTPBearer()


def hash_password(password: str) -> str:
    """將明文密碼轉為 bcrypt 雜湊"""
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    """驗證明文密碼是否與雜湊匹配"""
    return pwd_context.verify(plain, hashed)


def create_token(user_id: str, username: str) -> str:
    """產生 JWT Token"""
    expire = datetime.now(timezone.utc) + timedelta(minutes=EXPIRE_MINUTES)
    payload = {
        "sub": user_id,
        "username": username,
        "exp": expire,
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> dict:
    """解碼 JWT Token，失敗時拋出 HTTPException"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token 無效或已過期",
        )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """FastAPI 依賴注入：從 Authorization header 取得當前使用者"""
    return decode_token(credentials.credentials)
