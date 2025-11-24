from flask import Flask, request, jsonify
from openai import OpenAI
import os

app = Flask(__name__)

# 错误处理装饰器
@app.errorhandler(Exception)
def handle_exception(e):
    return jsonify({'error': '服务器内部错误', 'details': str(e)}), 500

@app.route('/api/chat', methods=['POST'])
def chat():
    try:
        # 获取请求数据
        data = request.get_json()
        message = data.get('message')
        api_key = data.get('apiKey')
        model_id = data.get('modelId', 'TBStars2-200B-A13B')
        chat_history = data.get('chatHistory', [])
        
        if not message or not api_key:
            return jsonify({'error': '缺少必要参数'}), 400
        
        # 构建系统提示词
        chat_history_text = "\n".join(chat_history) if chat_history and len(chat_history) > 0 else ""
        system_prompt = """你是一个温柔体贴的AI助手，专门用来哄女朋友开心。你的说话风格要：
1. 温柔、体贴、充满爱意
2. 多使用可爱的表情符号，如💕、❤️、🥰、😘等
3. 称呼对方为"宝贝"、"亲爱的"等亲昵称呼
4. 善于倾听和安慰，给予情感支持
5. 说话要简洁温馨，不要太长

"""
        
        if chat_history_text:
            system_prompt += f"参考以下聊天风格：\n{chat_history_text}\n\n"
        
        system_prompt += "请用这种风格回复用户的消息。"
        
        # 初始化iflow API客户端
        client = OpenAI(
            base_url="https://apis.iflow.cn/v1",
            api_key=api_key
        )
        
        # 构建消息历史
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": message}
        ]
        
        # 调用iflow API
        completion = client.chat.completions.create(
            model=model_id,
            messages=messages,
            temperature=0.8,
            max_tokens=800,
            stream=False
        )
        
        reply = completion.choices[0].message.content
        return jsonify({'reply': reply})
        
    except Exception as e:
        print(f"API调用失败: {str(e)}")
        return jsonify({'error': '调用失败', 'details': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3001, debug=True)
