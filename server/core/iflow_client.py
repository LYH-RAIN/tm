"""
iFlow API客户端封装
"""
from openai import AsyncOpenAI
from config.settings import settings
from typing import List, Dict, Any
import logging

logger = logging.getLogger(__name__)


class IflowClient:
    """iFlow API客户端"""
    
    def __init__(self):
        """
        初始化iFlow客户端，从配置中读取API密钥
        """
        self.client = AsyncOpenAI(
            base_url=settings.iflow_base_url,
            api_key=settings.iflow_api_key
        )
    
    async def chat_completion(
        self,
        model: str,
        messages: List[Dict[str, str]],
        temperature: float = None,
        max_tokens: int = None,
        **kwargs
    ) -> Any:
        """
        调用聊天完成接口
        
        Args:
            model: 模型ID
            messages: 消息列表
            temperature: 温度参数
            max_tokens: 最大token数
            **kwargs: 其他参数
            
        Returns:
            API响应结果
        """
        try:
            # 使用默认参数
            if temperature is None:
                temperature = settings.default_temperature
            if max_tokens is None:
                max_tokens = settings.default_max_tokens
            
            response = await self.client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                **kwargs
            )
            
            logger.info(f"iFlow API调用成功，模型: {model}")
            return response
            
        except Exception as e:
            logger.error(f"iFlow API调用失败: {str(e)}")
            raise Exception(f"调用iFlow API失败: {str(e)}")
    
    async def get_models(self) -> List[Dict[str, Any]]:
        """
        获取可用模型列表
        
        Returns:
            模型列表
        """
        try:
            response = await self.client.models.list()
            return response.data
        except Exception as e:
            logger.error(f"获取模型列表失败: {str(e)}")
            raise Exception(f"获取模型列表失败: {str(e)}")
