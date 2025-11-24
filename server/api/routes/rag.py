"""
RAG相关的API路由
"""
from fastapi import APIRouter, HTTPException
from api.models.chat import RAGStoreRequest, RAGSearchRequest, RAGSearchResult
from rag.rag_service import RAGService
from typing import List
import logging

# 设置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()

# 初始化RAG服务
rag_service = RAGService()


@router.post("/rag/store")
async def store_conversation(request: RAGStoreRequest):
    """
    存储聊天记录到RAG系统
    """
    try:
        await rag_service.store_conversation(
            user_message=request.user_message,
            ai_message=request.ai_message,
            conversation_id=request.conversation_id
        )
        return {"message": "聊天记录存储成功"}
    except Exception as e:
        logger.error(f"存储聊天记录错误: {str(e)}")
        raise HTTPException(status_code=500, detail=f"存储失败: {str(e)}")


@router.post("/rag/search", response_model=List[RAGSearchResult])
async def search_similar(request: RAGSearchRequest):
    """
    检索相似的历史对话
    """
    try:
        results = await rag_service.search_similar(
            query=request.query,
            top_k=request.top_k
        )
        return results
    except Exception as e:
        logger.error(f"检索相似对话错误: {str(e)}")
        raise HTTPException(status_code=500, detail=f"检索失败: {str(e)}")


@router.delete("/rag/clear")
async def clear_history():
    """
    清除所有历史记录
    """
    try:
        await rag_service.clear_history()
        return {"message": "历史记录清除成功"}
    except Exception as e:
        logger.error(f"清除历史记录错误: {str(e)}")
        raise HTTPException(status_code=500, detail=f"清除失败: {str(e)}")


@router.get("/rag/stats")
async def get_stats():
    """
    获取RAG系统统计信息
    """
    try:
        stats = await rag_service.get_stats()
        return stats
    except Exception as e:
        logger.error(f"获取统计信息错误: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取统计信息失败: {str(e)}")
