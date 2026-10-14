"""
用戶認證 API 路由
處理註冊、登入、取得用戶資料
"""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr

from database import get_db
from auth import hash_password, verify_password, create_token, get_current_user

router = APIRouter(prefix="/api/auth", tags=["認證"])


# ─── 請求/回應模型 ───

class RegisterRequest(BaseModel):
    username: str
    email: str
    password: str
    display_name: str = ""


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    token: str
    user: dict


class UserResponse(BaseModel):
    id: str
    username: str
    email: str
    display_name: str
    bio: str | None = ""
    avatar_url: str | None = None
    is_google: int = 0
    membership_tier: str = "free"
    points_balance: int = 100
    created_at: str | None = None


# ─── API 端點 ───

@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(req: RegisterRequest, cur=Depends(get_db)):
    """
    註冊新用戶

    - 檢查 username 和 email 是否已存在
    - 密碼以 bcrypt 雜湊儲存
    - 回傳 JWT Token
    """
    # 檢查重複
    await cur.execute(
        "SELECT id FROM users WHERE username = %s OR email = %s",
        (req.username, req.email),
    )
    existing = await cur.fetchone()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="帳號或 Email 已被使用",
        )

    user_id = str(uuid.uuid4())[:8]  # 簡短 ID，和現有 SQLite 格式一致
    hashed = hash_password(req.password)
    now = datetime.now().isoformat()

    await cur.execute(
        """
        INSERT INTO users (id, username, email, hashed_password, display_name, created_at)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (user_id, req.username, req.email, hashed, req.display_name or req.username, now),
    )

    token = create_token(user_id, req.username)
    user = {
        "id": user_id,
        "username": req.username,
        "email": req.email,
        "display_name": req.display_name or req.username,
        "bio": "",
        "avatar_url": None,
        "is_google": 0,
        "membership_tier": "free",
        "points_balance": 100,
        "created_at": now,
    }
    return {"token": token, "user": user}


@router.post("/login", response_model=TokenResponse)
async def login(req: LoginRequest, cur=Depends(get_db)):
    """
    用戶登入

    - 支援 username 或 email 登入
    - 驗證密碼後回傳 JWT Token
    """
    await cur.execute(
        "SELECT * FROM users WHERE (username = %s OR email = %s) AND deleted_at IS NULL",
        (req.username, req.username),
    )
    user = await cur.fetchone()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="帳號不存在",
        )

    if not verify_password(req.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="密碼錯誤",
        )

    token = create_token(user["id"], user["username"])

    # 移除敏感欄位
    safe_user = {k: v for k, v in user.items() if k != "hashed_password"}
    # 將 datetime 轉字串
    for k, v in safe_user.items():
        if isinstance(v, datetime):
            safe_user[k] = v.isoformat()

    return {"token": token, "user": safe_user}


@router.get("/me")
async def get_me(current_user: dict = Depends(get_current_user), cur=Depends(get_db)):
    """
    取得當前登入的用戶資料（需要 Bearer Token）
    """
    await cur.execute(
        "SELECT * FROM users WHERE id = %s AND deleted_at IS NULL",
        (current_user["sub"],),
    )
    user = await cur.fetchone()
    if not user:
        raise HTTPException(status_code=404, detail="用戶不存在")

    safe_user = {k: v for k, v in user.items() if k != "hashed_password"}
    for k, v in safe_user.items():
        if isinstance(v, datetime):
            safe_user[k] = v.isoformat()
    return safe_user


@router.put("/me")
async def update_me(
    updates: dict,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """
    更新當前用戶資料（需要 Bearer Token）

    可更新欄位：display_name, bio, avatar_url, theme_color_idx, is_dark_mode,
    font_size_factor, calendar_view_mode, social_feed_layout, nav_bar_items,
    show_floating_nav_bar, gemini_api_key, push_notifications_enabled, language
    """
    allowed = {
        "display_name", "bio", "avatar_url", "theme_color_idx", "is_dark_mode",
        "font_size_factor", "calendar_view_mode", "social_feed_layout",
        "nav_bar_items", "show_floating_nav_bar", "gemini_api_key",
        "push_notifications_enabled", "language", "has_seen_tour",
        "membership_tier", "membership_expires_at", "points_balance",
    }
    filtered = {k: v for k, v in updates.items() if k in allowed}

    if not filtered:
        raise HTTPException(status_code=400, detail="沒有可更新的欄位")

    set_clause = ", ".join(f"`{k}` = %s" for k in filtered)
    values = list(filtered.values()) + [current_user["sub"]]

    await cur.execute(
        f"UPDATE users SET {set_clause} WHERE id = %s",
        values,
    )
    return {"message": "更新成功", "updated": list(filtered.keys())}
