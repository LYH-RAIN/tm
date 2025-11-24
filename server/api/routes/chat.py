"""
聊天相关的API路由
"""
from fastapi import APIRouter, HTTPException
from api.models.chat import ChatRequest, ChatResponse
from core.iflow_client import IflowClient
# from rag.rag_service import RAGService  # 暂时禁用RAG功能
import logging

# 设置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()

# 初始化服务
# rag_service = RAGService()  # 暂时禁用RAG功能


@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    聊天接口，与现有前端保持兼容
    """
    try:
        # 初始化iFlow客户端，从配置中读取API密钥
        iflow_client = IflowClient()
        
        # 检索相关历史对话（暂时禁用）
        # relevant_history = await rag_service.search_similar(request.message)
        relevant_history = []  # 暂时使用空列表
        
        # 构建系统提示词
        system_prompt = """你是一个温柔体贴的AI助手，专门用来哄女朋友开心。你的说话风格要：
1. 温柔、体贴、充满爱意
2. 多使用可爱的表情符号，如💕、❤️、🥰、😘等
3. 称呼对方为"宝贝"、"亲爱的"等亲昵称呼
4. 善于倾听和安慰，给予情感支持
5. 说话要简洁温馨，不要太长

"""
        
        # 添加RAG检索到的相关历史对话
        if relevant_history:
            system_prompt += "参考以下历史对话风格：\n"
            for item in relevant_history:
                system_prompt += f"{item['role']}: {item['content']}\n"
            system_prompt += "\n"
        
        # 添加用户提供的聊天历史样本
        if request.chatHistory and len(request.chatHistory) > 0:
            system_prompt += f"参考以下聊天风格：\n{chr(10).join(request.chatHistory)}\n\n"
        
        system_prompt += "请用这种风格回复用户的消息。"
        
        # 调用iFlow API
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": request.message}
        ]
        
        response = await iflow_client.chat_completion(
            model=request.modelId,
            messages=messages
        )
        
        ai_reply = response.choices[0].message.content
        
        # 存储聊天记录到RAG系统（暂时禁用）
        # await rag_service.store_conversation(
        #     user_message=request.message,
        #     ai_message=ai_reply
        # )
        
        return ChatResponse(reply=ai_reply)
        
    except Exception as e:
        logger.error(f"聊天接口错误: {str(e)}")
        raise HTTPException(status_code=500, detail=f"调用失败: {str(e)}")
