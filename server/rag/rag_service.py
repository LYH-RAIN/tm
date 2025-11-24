"""
RAG服务核心实现
"""
import os
import uuid
import asyncio
from datetime import datetime
from typing import List, Dict, Any, Optional
from sentence_transformers import SentenceTransformer
import chromadb
from chromadb.config import Settings
from config.settings import settings
import logging

logger = logging.getLogger(__name__)


class RAGService:
    """RAG服务类"""
    
    def __init__(self):
        """初始化RAG服务"""
        self.embedding_model = None
        self.chroma_client = None
        self.collection = None
        self._initialized = False
    
    async def _initialize(self):
        """异步初始化"""
        if self._initialized:
            return
        
        try:
            # 初始化Embedding模型
            logger.info("正在加载Embedding模型...")
            self.embedding_model = SentenceTransformer(settings.embedding_model_name)
            
            # 创建ChromaDB数据目录
            os.makedirs(settings.chroma_db_path, exist_ok=True)
            
            # 初始化ChromaDB客户端
            self.chroma_client = chromadb.PersistentClient(
                path=settings.chroma_db_path,
                settings=Settings(anonymized_telemetry=False)
            )
            
            # 获取或创建集合
            collection_name = "chat_history"
            try:
                self.collection = self.chroma_client.get_collection(collection_name)
            except ValueError:
                # 集合不存在，创建新集合
                # 使用None作为embedding_function，避免使用默认的ONNX embedding
                self.collection = self.chroma_client.create_collection(
                    name=collection_name,
                    metadata={"description": "聊天历史记录向量存储"},
                    embedding_function=None  # 禁用默认embedding函数，使用自定义embedding
                )
            
            self._initialized = True
            logger.info("RAG服务初始化完成")
            
        except Exception as e:
            logger.error(f"RAG服务初始化失败: {str(e)}")
            raise
    
    async def store_conversation(
        self, 
        user_message: str, 
        ai_message: str, 
        conversation_id: Optional[str] = None
    ) -> bool:
        """
        存储对话到向量数据库
        
        Args:
            user_message: 用户消息
            ai_message: AI回复
            conversation_id: 对话ID，可选
            
        Returns:
            是否存储成功
        """
        try:
            await self._initialize()
            
            if not conversation_id:
                conversation_id = str(uuid.uuid4())
            
            timestamp = datetime.now().isoformat()
            
            # 存储用户消息
            user_id = f"{conversation_id}_user_{int(datetime.now().timestamp() * 1000)}"
            user_embedding = self.embedding_model.encode([user_message])[0].tolist()
            
            self.collection.add(
                embeddings=[user_embedding],
                documents=[user_message],
                metadatas=[{
                    "role": "user",
                    "conversation_id": conversation_id,
                    "timestamp": timestamp,
                    "message_type": "user"
                }],
                ids=[user_id]
            )
            
            # 存储AI消息
            ai_id = f"{conversation_id}_assistant_{int(datetime.now().timestamp() * 1000) + 1}"
            ai_embedding = self.embedding_model.encode([ai_message])[0].tolist()
            
            self.collection.add(
                embeddings=[ai_embedding],
                documents=[ai_message],
                metadatas=[{
                    "role": "assistant",
                    "conversation_id": conversation_id,
                    "timestamp": timestamp,
                    "message_type": "assistant"
                }],
                ids=[ai_id]
            )
            
            logger.info(f"成功存储对话，对话ID: {conversation_id}")
            return True
            
        except Exception as e:
            logger.error(f"存储对话失败: {str(e)}")
            return False
    
    async def search_similar(
        self, 
        query: str, 
        top_k: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        检索相似的历史对话
        
        Args:
            query: 查询文本
            top_k: 返回的结果数量
            
        Returns:
            相似对话列表
        """
        try:
            await self._initialize()
            
            if not top_k:
                top_k = settings.rag_top_k
            
            # 生成查询向量
            query_embedding = self.embedding_model.encode([query])[0].tolist()
            
            # 检索相似向量
            results = self.collection.query(
                query_embeddings=[query_embedding],
                n_results=top_k,
                include=["documents", "metadatas", "distances"]
            )
            
            # 格式化结果
            formatted_results = []
            if results['documents'] and len(results['documents']) > 0:
                for i, (doc, metadata, distance) in enumerate(zip(
                    results['documents'][0], 
                    results['metadatas'][0], 
                    results['distances'][0]
                )):
                    # 计算相似度分数（距离越小，相似度越高）
                    similarity = 1.0 - distance
                    
                    # 只返回相似度高于阈值的结果
                    if similarity >= settings.rag_similarity_threshold:
                        formatted_results.append({
                            "content": doc,
                            "role": metadata["role"],
                            "similarity": similarity,
                            "timestamp": metadata["timestamp"],
                            "conversation_id": metadata["conversation_id"]
                        })
            
            # 按相似度排序
            formatted_results.sort(key=lambda x: x["similarity"], reverse=True)
            
            logger.info(f"检索到 {len(formatted_results)} 条相似对话")
            return formatted_results
            
        except Exception as e:
            logger.error(f"检索相似对话失败: {str(e)}")
            return []
    
    async def clear_history(self) -> bool:
        """
        清除所有历史记录
        
        Returns:
            是否清除成功
        """
        try:
            await self._initialize()
            
            # 删除集合
            self.chroma_client.delete_collection("chat_history")
            
            # 重新创建集合
            self.collection = self.chroma_client.create_collection(
                name="chat_history",
                metadata={"description": "聊天历史记录向量存储"}
            )
            
            logger.info("成功清除所有历史记录")
            return True
            
        except Exception as e:
            logger.error(f"清除历史记录失败: {str(e)}")
            return False
    
    async def get_stats(self) -> Dict[str, Any]:
        """
        获取RAG系统统计信息
        
        Returns:
            统计信息字典
        """
        try:
            await self._initialize()
            
            # 获取集合信息
            collection_count = self.collection.count()
            
            # 计算不同角色的消息数量
            user_results = self.collection.get(
                where={"role": "user"},
                include=["metadatas"]
            )
            assistant_results = self.collection.get(
                where={"role": "assistant"}, 
                include=["metadatas"]
            )
            
            user_count = len(user_results['metadatas']) if user_results['metadatas'] else 0
            assistant_count = len(assistant_results['metadatas']) if assistant_results['metadatas'] else 0
            
            # 获取时间范围
            all_results = self.collection.get(include=["metadatas"])
            timestamps = []
            if all_results['metadatas']:
                for metadata in all_results['metadatas']:
                    if 'timestamp' in metadata:
                        timestamps.append(metadata['timestamp'])
            
            earliest_time = min(timestamps) if timestamps else None
            latest_time = max(timestamps) if timestamps else None
            
            stats = {
                "total_messages": collection_count,
                "user_messages": user_count,
                "assistant_messages": assistant_count,
                "earliest_message": earliest_time,
                "latest_message": latest_time,
                "embedding_model": settings.embedding_model_name,
                "storage_path": settings.chroma_db_path
            }
            
            logger.info(f"获取统计信息成功: {stats}")
            return stats
            
        except Exception as e:
            logger.error(f"获取统计信息失败: {str(e)}")
            return {
                "total_messages": 0,
                "user_messages": 0,
                "assistant_messages": 0,
                "error": str(e)
            }
