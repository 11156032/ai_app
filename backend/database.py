"""
資料庫連線管理模組
使用 aiomysql 非同步連線池連接 MySQL
"""

import os
import aiomysql
from dotenv import load_dotenv

load_dotenv()

# ── 連線池（全域單例）──
_pool: aiomysql.Pool | None = None


async def get_pool() -> aiomysql.Pool:
    """取得或建立全域連線池"""
    global _pool
    if _pool is None:
        _pool = await aiomysql.create_pool(
            host=os.getenv("DB_HOST", "140.131.114.242"),
            port=int(os.getenv("DB_PORT", "3306")),
            user=os.getenv("DB_USER", "root"),
            password=os.getenv("DB_PASSWORD", ""),
            db=os.getenv("DB_NAME", "ai_app"),
            charset="utf8mb4",
            autocommit=True,
            minsize=2,
            maxsize=10,
        )
    return _pool


async def close_pool():
    """關閉連線池（APP 關閉時呼叫）"""
    global _pool
    if _pool is not None:
        _pool.close()
        await _pool.wait_closed()
        _pool = None


async def get_db():
    """FastAPI 依賴注入：取得一個 DB 連線，用完自動歸還"""
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            yield cur
