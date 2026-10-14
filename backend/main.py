"""
AI 學習 App — FastAPI 後端主程式
=================================

啟動方式：
  cd backend
  pip install -r requirements.txt
  python main.py

API 文件：
  啟動後瀏覽 http://localhost:8000/docs（Swagger UI）
"""

import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import get_pool, close_pool
from routers.auth_router import router as auth_router
from routers.posts_router import router as posts_router
from routers.groups_router import router as groups_router

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """APP 生命週期：啟動時建立連線池，關閉時釋放"""
    print("🚀 啟動中... 建立 MySQL 連線池")
    await get_pool()
    print("✅ MySQL 連線池就緒")
    yield
    print("🛑 關閉 MySQL 連線池...")
    await close_pool()


app = FastAPI(
    title="AI 學習 App API",
    description="Flutter AI 學習 App 的雲端後端 API",
    version="1.0.0",
    lifespan=lifespan,
)

# ─── CORS 設定（允許 Flutter App 跨域存取）───
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 開發階段先允許所有來源；上線時應限制
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── 註冊路由 ───
app.include_router(auth_router)
app.include_router(posts_router)
app.include_router(groups_router)


# ─── 健康檢查 ───
@app.get("/", tags=["系統"])
async def root():
    return {
        "status": "ok",
        "message": "AI 學習 App API 運行中 🚀",
        "docs": "/docs",
    }


@app.get("/health", tags=["系統"])
async def health():
    """健康檢查端點，可用於監控"""
    try:
        pool = await get_pool()
        async with pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("SELECT 1")
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "database": str(e)}


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("API_HOST", "0.0.0.0")
    port = int(os.getenv("API_PORT", "8000"))
    print(f"\n{'='*50}")
    print(f"  AI 學習 App API Server")
    print(f"  🌐 http://localhost:{port}")
    print(f"  📚 http://localhost:{port}/docs")
    print(f"  🗄️  MySQL: {os.getenv('DB_HOST', '140.131.114.242')}")
    print(f"{'='*50}\n")
    uvicorn.run("main:app", host=host, port=port, reload=True)
