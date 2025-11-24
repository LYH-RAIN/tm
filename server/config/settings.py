"""
配置管理模块
"""
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """应用配置"""
    
    # 服务配置
    host: str = "0.0.0.0"
    port: int = 3001
    
    # iFlow API配置
    iflow_base_url: str = "https://apis.iflow.cn/v1"
    iflow_api_key: str  # iFlow API密钥，从环境变量中读取
    default_model: str = "TBStars2-200B-A13B"
    default_temperature: float = 0.8
    default_max_tokens: int = 800
    
    # RAG配置
    chroma_db_path: str = "./data/chromadb"
    embedding_model_name: str = "sentence-transformers/all-MiniLM-L6-v2"
    rag_top_k: int = 5
    rag_similarity_threshold: float = 0.7
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


# 全局设置实例
settings = Settings()
