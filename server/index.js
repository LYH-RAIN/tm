const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const axios = require('axios');

const app = express();
const PORT = 3001;

app.use(cors());
app.use(bodyParser.json());

app.post('/api/chat', async (req, res) => {
  try {
    const { message, apiKey, modelId, chatHistory } = req.body;

    const systemPrompt = `你是一个温柔体贴的AI助手，专门用来哄女朋友开心。你的说话风格要：
1. 温柔、体贴、充满爱意
2. 多使用可爱的表情符号，如💕、❤️、🥰、😘等
3. 称呼对方为"宝贝"、"亲爱的"等亲昵称呼
4. 善于倾听和安慰，给予情感支持
5. 说话要简洁温馨，不要太长

${chatHistory && chatHistory.length > 0 ? `参考以下聊天风格：\n${chatHistory.join('\n')}` : ''}

请用这种风格回复用户的消息。`;

    const response = await axios.post(
      'https://apis.iflow.cn/v1/chat/completions',
      {
        model: modelId || 'TBStars2-200B-A13B',
        messages: [
          {
            role: 'system',
            content: systemPrompt
          },
          {
            role: 'user',
            content: message
          }
        ],
        temperature: 0.8,
        max_tokens: 800,
        stream: false
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const reply = response.data.choices[0].message.content;
    res.json({ reply });

  } catch (error) {
    console.error('API调用失败:', error.response?.data || error.message);
    res.status(500).json({ 
      error: '调用失败',
      details: error.response?.data || error.message 
    });
  }
});

app.listen(PORT, () => {
  console.log(`后端服务运行在 http://localhost:${PORT}`);
});
