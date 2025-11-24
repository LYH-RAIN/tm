"""
FastAPI应用入口文件
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes.chat import router as chat_router
# from api.routes.rag import router as rag_router  # 暂时禁用RAG功能
import uvicorn

# 创建FastAPI应用
app = FastAPI(
    title="哄汤敏系统 API",
    description="基于Python FastAPI的情感陪伴聊天系统",
    version="2.0.0"
)

# 配置CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8520"],  # 前端开发服务器地址
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(chat_router, prefix="/api")
# app.include_router(rag_router, prefix="/api")  # 暂时禁用RAG功能

@app.get("/")
async def root():
    return {"message": "哄汤敏系统后端服务运行中 💕"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=3001)
