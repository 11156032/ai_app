"""
社群群組 API 路由
處理群組 CRUD、成員管理、邀請連結
"""

import secrets
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from database import get_db
from auth import get_current_user

router = APIRouter(prefix="/api/groups", tags=["社群群組"])


# ─── 請求模型 ───

class CreateGroupRequest(BaseModel):
    name: str
    description: str = ""
    icon_emoji: str = "📚"
    type: str = "public"
    join_requires_approval: bool = False
    tags: list[str] = []


class UpdateGroupRequest(BaseModel):
    name: str | None = None
    description: str | None = None
    icon_emoji: str | None = None
    type: str | None = None
    join_requires_approval: bool | None = None


# ─── API 端點 ───

@router.get("")
async def get_my_groups(
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """取得我加入的所有群組"""
    user_id = current_user["sub"]
    await cur.execute(
        """
        SELECT cg.*,
               COALESCE(gm.role, 'owner') as my_role,
               COALESCE(gm.status, 'active') as my_status,
               COALESCE(gm.last_read_at, '1970-01-01') as last_read_at,
               COALESCE(gm.is_muted, 0) as is_muted,
               (SELECT COUNT(*) FROM group_members gm2
                WHERE gm2.group_id = cg.id AND gm2.status = 'pending') as pending_count,
               (SELECT COUNT(*) FROM posts p
                WHERE p.group_id = cg.id
                AND p.created_at > COALESCE(gm.last_read_at, '1970-01-01')) as unread_count
        FROM community_groups cg
        LEFT JOIN group_members gm ON cg.id = gm.group_id AND gm.user_id = %s
        WHERE (gm.user_id = %s AND gm.status = 'active') OR cg.owner_id = %s
        ORDER BY
            CASE WHEN COALESCE(gm.is_muted, 0) = 1 THEN 1 ELSE 0 END ASC,
            unread_count DESC,
            cg.created_at DESC
        """,
        (user_id, user_id, user_id),
    )
    groups = await cur.fetchall()
    result = []
    for g in groups:
        d = dict(g)
        for k, v in d.items():
            if isinstance(v, datetime):
                d[k] = v.isoformat()
        result.append(d)
    return {"groups": result}


@router.post("", status_code=201)
async def create_group(
    req: CreateGroupRequest,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """建立新群組"""
    user_id = current_user["sub"]
    token = secrets.token_hex(12)
    now = datetime.now().isoformat()
    import json

    await cur.execute(
        """
        INSERT INTO community_groups
            (name, description, icon_emoji, type, owner_id, tags,
             member_count, invite_token, invite_link_active,
             join_requires_approval, created_at)
        VALUES (%s, %s, %s, %s, %s, %s, 1, %s, 1, %s, %s)
        """,
        (
            req.name, req.description, req.icon_emoji, req.type,
            user_id, json.dumps(req.tags), token,
            1 if req.join_requires_approval else 0, now,
        ),
    )
    await cur.execute("SELECT LAST_INSERT_ID() as id")
    row = await cur.fetchone()
    group_id = row["id"]

    # 自動加入 owner
    await cur.execute(
        """
        INSERT INTO group_members (group_id, user_id, role, status, joined_at, last_read_at)
        VALUES (%s, %s, 'owner', 'active', %s, %s)
        """,
        (group_id, user_id, now, now),
    )

    return {"id": group_id, "invite_token": token, "message": "群組已建立"}


@router.get("/discover")
async def discover_groups(
    cur=Depends(get_db),
):
    """探索公開群組（不需登入）"""
    await cur.execute(
        """
        SELECT cg.*,
               u.display_name as owner_name, u.avatar_url as owner_avatar
        FROM community_groups cg
        JOIN users u ON cg.owner_id = u.id
        WHERE cg.type = 'public'
        ORDER BY cg.member_count DESC, cg.created_at DESC
        LIMIT 50
        """
    )
    groups = await cur.fetchall()
    result = []
    for g in groups:
        d = dict(g)
        for k, v in d.items():
            if isinstance(v, datetime):
                d[k] = v.isoformat()
        result.append(d)
    return {"groups": result}


@router.post("/{group_id}/join")
async def join_group(
    group_id: int,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """加入群組"""
    user_id = current_user["sub"]

    # 檢查群組
    await cur.execute("SELECT * FROM community_groups WHERE id = %s", (group_id,))
    group = await cur.fetchone()
    if not group:
        raise HTTPException(status_code=404, detail="群組不存在")

    # 檢查是否已加入
    await cur.execute(
        "SELECT id, status FROM group_members WHERE group_id = %s AND user_id = %s",
        (group_id, user_id),
    )
    existing = await cur.fetchone()
    if existing:
        if existing["status"] == "active":
            raise HTTPException(status_code=409, detail="你已經是群組成員")
        if existing["status"] == "pending":
            raise HTTPException(status_code=409, detail="申請審核中")

    now = datetime.now().isoformat()
    join_status = "pending" if group["join_requires_approval"] else "active"

    await cur.execute(
        """
        INSERT INTO group_members (group_id, user_id, role, status, joined_at, last_read_at)
        VALUES (%s, %s, 'member', %s, %s, %s)
        """,
        (group_id, user_id, join_status, now, now),
    )

    if join_status == "active":
        await cur.execute(
            "UPDATE community_groups SET member_count = member_count + 1 WHERE id = %s",
            (group_id,),
        )

    return {"status": join_status, "message": "已加入群組" if join_status == "active" else "已送出申請"}


@router.post("/{group_id}/leave")
async def leave_group(
    group_id: int,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """離開群組"""
    user_id = current_user["sub"]

    # 不能讓 owner 離開
    await cur.execute(
        "SELECT owner_id FROM community_groups WHERE id = %s",
        (group_id,),
    )
    group = await cur.fetchone()
    if group and group["owner_id"] == user_id:
        raise HTTPException(status_code=403, detail="群主不能離開群組，請先轉讓群主")

    await cur.execute(
        "DELETE FROM group_members WHERE group_id = %s AND user_id = %s",
        (group_id, user_id),
    )
    await cur.execute(
        "UPDATE community_groups SET member_count = GREATEST(member_count - 1, 0) WHERE id = %s",
        (group_id,),
    )
    return {"message": "已離開群組"}


@router.get("/{group_id}/members")
async def get_members(
    group_id: int,
    cur=Depends(get_db),
):
    """取得群組成員列表"""
    await cur.execute(
        """
        SELECT gm.*, u.username, u.display_name, u.avatar_url, u.avatar_color
        FROM group_members gm
        JOIN users u ON gm.user_id = u.id
        WHERE gm.group_id = %s
        ORDER BY
            CASE gm.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END,
            gm.joined_at ASC
        """,
        (group_id,),
    )
    members = await cur.fetchall()
    result = []
    for m in members:
        d = dict(m)
        for k, v in d.items():
            if isinstance(v, datetime):
                d[k] = v.isoformat()
        result.append(d)
    return {"members": result}


@router.post("/join-by-token/{token}")
async def join_by_token(
    token: str,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """透過邀請連結加入群組"""
    await cur.execute(
        "SELECT * FROM community_groups WHERE invite_token = %s AND invite_link_active = 1",
        (token,),
    )
    group = await cur.fetchone()
    if not group:
        raise HTTPException(status_code=404, detail="邀請連結無效或已停用")

    # 複用 join_group 邏輯
    user_id = current_user["sub"]
    await cur.execute(
        "SELECT id FROM group_members WHERE group_id = %s AND user_id = %s",
        (group["id"], user_id),
    )
    if await cur.fetchone():
        return {"group_id": group["id"], "message": "你已經是群組成員"}

    now = datetime.now().isoformat()
    await cur.execute(
        """
        INSERT INTO group_members (group_id, user_id, role, status, joined_at, last_read_at)
        VALUES (%s, %s, 'member', 'active', %s, %s)
        """,
        (group["id"], user_id, now, now),
    )
    await cur.execute(
        "UPDATE community_groups SET member_count = member_count + 1 WHERE id = %s",
        (group["id"],),
    )
    return {"group_id": group["id"], "message": "已透過邀請連結加入群組"}
