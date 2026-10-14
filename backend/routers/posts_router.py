"""
社群貼文 API 路由
處理貼文 CRUD、按讚、留言、收藏
"""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from database import get_db
from auth import get_current_user

router = APIRouter(prefix="/api/posts", tags=["社群貼文"])


# ─── 請求模型 ───

class CreatePostRequest(BaseModel):
    content: str
    type: str = "text"
    attached_data: dict | None = None
    group_id: int | None = None


class UpdatePostRequest(BaseModel):
    content: str


class CreateCommentRequest(BaseModel):
    text: str
    parent_id: int = 0


# ─── API 端點 ───

@router.get("")
async def get_posts(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    group_id: Optional[int] = None,
    user_id: Optional[str] = None,
    cur=Depends(get_db),
):
    """
    取得貼文列表（公開，不需登入）

    - 支援分頁 (page, limit)
    - 可篩選 group_id 或 user_id
    - 回傳包含作者資訊和互動統計
    """
    offset = (page - 1) * limit
    where_clauses = []
    params = []

    if group_id is not None:
        where_clauses.append("p.group_id = %s")
        params.append(group_id)
    else:
        where_clauses.append("p.group_id IS NULL")

    if user_id:
        where_clauses.append("p.user_id = %s")
        params.append(user_id)

    where_sql = " AND ".join(where_clauses) if where_clauses else "1=1"

    await cur.execute(
        f"""
        SELECT p.*,
               u.username, u.display_name, u.avatar_url, u.avatar_color,
               (SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id) as like_count,
               (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) as comment_count
        FROM posts p
        JOIN users u ON p.user_id = u.id
        WHERE {where_sql}
        ORDER BY p.created_at DESC
        LIMIT %s OFFSET %s
        """,
        params + [limit, offset],
    )
    posts = await cur.fetchall()

    # 轉換 datetime
    result = []
    for post in posts:
        p = dict(post)
        for k, v in p.items():
            if isinstance(v, datetime):
                p[k] = v.isoformat()
        result.append(p)

    return {"posts": result, "page": page, "limit": limit}


@router.post("", status_code=201)
async def create_post(
    req: CreatePostRequest,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """建立新貼文（需要登入）"""
    import json

    now = datetime.now().isoformat()
    await cur.execute(
        """
        INSERT INTO posts (user_id, group_id, content, type, attached_data, created_at)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (
            current_user["sub"],
            req.group_id,
            req.content,
            req.type,
            json.dumps(req.attached_data or {}),
            now,
        ),
    )
    # 取得剛插入的 ID
    await cur.execute("SELECT LAST_INSERT_ID() as id")
    row = await cur.fetchone()
    post_id = row["id"]

    return {"id": post_id, "message": "貼文已發佈"}


@router.put("/{post_id}")
async def update_post(
    post_id: int,
    req: UpdatePostRequest,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """編輯貼文（只能編輯自己的）"""
    await cur.execute(
        "SELECT user_id FROM posts WHERE id = %s",
        (post_id,),
    )
    post = await cur.fetchone()
    if not post:
        raise HTTPException(status_code=404, detail="貼文不存在")
    if post["user_id"] != current_user["sub"]:
        raise HTTPException(status_code=403, detail="無權編輯此貼文")

    await cur.execute(
        "UPDATE posts SET content = %s, is_edited = 1 WHERE id = %s",
        (req.content, post_id),
    )
    return {"message": "貼文已更新"}


@router.delete("/{post_id}")
async def delete_post(
    post_id: int,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """刪除貼文（只能刪除自己的）"""
    await cur.execute(
        "SELECT user_id FROM posts WHERE id = %s",
        (post_id,),
    )
    post = await cur.fetchone()
    if not post:
        raise HTTPException(status_code=404, detail="貼文不存在")
    if post["user_id"] != current_user["sub"]:
        raise HTTPException(status_code=403, detail="無權刪除此貼文")

    await cur.execute("DELETE FROM posts WHERE id = %s", (post_id,))
    return {"message": "貼文已刪除"}


@router.post("/{post_id}/like")
async def toggle_like(
    post_id: int,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """按讚/取消按讚"""
    user_id = current_user["sub"]

    await cur.execute(
        "SELECT id FROM post_likes WHERE post_id = %s AND user_id = %s",
        (post_id, user_id),
    )
    existing = await cur.fetchone()

    if existing:
        await cur.execute(
            "DELETE FROM post_likes WHERE post_id = %s AND user_id = %s",
            (post_id, user_id),
        )
        await cur.execute(
            "UPDATE posts SET likes = GREATEST(likes - 1, 0) WHERE id = %s",
            (post_id,),
        )
        return {"liked": False, "message": "已取消按讚"}
    else:
        await cur.execute(
            "INSERT INTO post_likes (post_id, user_id) VALUES (%s, %s)",
            (post_id, user_id),
        )
        await cur.execute(
            "UPDATE posts SET likes = likes + 1 WHERE id = %s",
            (post_id,),
        )
        return {"liked": True, "message": "已按讚"}


@router.post("/{post_id}/bookmark")
async def toggle_bookmark(
    post_id: int,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """收藏/取消收藏"""
    user_id = current_user["sub"]

    await cur.execute(
        "SELECT id FROM post_bookmarks WHERE post_id = %s AND user_id = %s",
        (post_id, user_id),
    )
    existing = await cur.fetchone()

    if existing:
        await cur.execute(
            "DELETE FROM post_bookmarks WHERE post_id = %s AND user_id = %s",
            (post_id, user_id),
        )
        return {"bookmarked": False}
    else:
        await cur.execute(
            "INSERT INTO post_bookmarks (post_id, user_id) VALUES (%s, %s)",
            (post_id, user_id),
        )
        return {"bookmarked": True}


@router.get("/{post_id}/comments")
async def get_comments(post_id: int, cur=Depends(get_db)):
    """取得貼文留言"""
    await cur.execute(
        """
        SELECT c.*, u.username, u.display_name, u.avatar_url, u.avatar_color
        FROM comments c
        JOIN users u ON c.user_id = u.id
        WHERE c.post_id = %s
        ORDER BY c.created_at ASC
        """,
        (post_id,),
    )
    comments = await cur.fetchall()
    result = []
    for comment in comments:
        c = dict(comment)
        for k, v in c.items():
            if isinstance(v, datetime):
                c[k] = v.isoformat()
        result.append(c)
    return {"comments": result}


@router.post("/{post_id}/comments", status_code=201)
async def create_comment(
    post_id: int,
    req: CreateCommentRequest,
    current_user: dict = Depends(get_current_user),
    cur=Depends(get_db),
):
    """新增留言（需要登入）"""
    now = datetime.now().isoformat()
    await cur.execute(
        """
        INSERT INTO comments (post_id, user_id, text, parent_id, created_at)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (post_id, current_user["sub"], req.text, req.parent_id, now),
    )
    await cur.execute("SELECT LAST_INSERT_ID() as id")
    row = await cur.fetchone()
    return {"id": row["id"], "message": "留言已發佈"}
