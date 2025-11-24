"""
聊天相关的数据模型
"""
from pydantic import BaseModel
from typing import List, Optional


class ChatMessage(BaseModel):
    """聊天消息模型"""
    role: str  # "user" 或 "assistant"
    content: str


class ChatRequest(BaseModel):
    """聊天请求模型"""
    message: str
    modelId: str
    chatHistory: Optional[List[str]] = []


class ChatResponse(BaseModel):
    """聊天响应模型"""
    reply: str


class RAGStoreRequest(BaseModel):
    """RAG存储请求模型"""
    user_message: str
    ai_message: str
    conversation_id: Optional[str] = None


class RAGSearchRequest(BaseModel):
    """RAG检索请求模型"""
    query: str
    top_k: Optional[int] = 5


class RAGSearchResult(BaseModel):
    """RAG检索结果模型"""
    content: str
    role: str
    similarity: float
    timestamp: str
