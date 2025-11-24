import React, { useState, useRef, useEffect } from 'react';
import axios from 'axios';

function ChatInterface({ config }) {
  const [messages, setMessages] = useState([]);
  const [inputText, setInputText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const sendMessage = async () => {
    if (!inputText.trim() || isLoading) return;

    if (!config.modelId) {
      alert('请先在设置中配置模型ID');
      return;
    }

    const userMessage = {
      role: 'user',
      content: inputText,
      timestamp: new Date().toLocaleTimeString()
    };

    setMessages(prev => [...prev, userMessage]);
    setInputText('');
    setIsLoading(true);

    try {
      const response = await axios.post('http://localhost:3001/api/chat', {
        message: inputText,
        modelId: config.modelId,
        chatHistory: config.chatHistory
      });

      const aiMessage = {
        role: 'assistant',
        content: response.data.reply,
        timestamp: new Date().toLocaleTimeString()
      };

      setMessages(prev => [...prev, aiMessage]);
    } catch (error) {
      console.error('发送消息失败:', error);
      const errorMessage = {
        role: 'assistant',
        content: '抱歉宝贝，我现在有点累了，稍后再聊好吗？💕',
        timestamp: new Date().toLocaleTimeString()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  return (
    <div className="bg-white/90 backdrop-blur-sm rounded-3xl shadow-2xl overflow-hidden">
      <div className="bg-gradient-to-r from-pink-medium to-purple-light p-6">
        <div className="flex items-center justify-center space-x-3">
          <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center animate-pulse-slow">
            <i className="fas fa-robot text-pink-deep text-2xl"></i>
          </div>
          <div>
            <h2 className="text-white text-xl font-bold">AI小甜心</h2>
            <p className="text-white/80 text-sm">随时为你服务 💝</p>
          </div>
        </div>
      </div>

      <div className="h-[500px] overflow-y-auto p-6 space-y-4">
        {messages.length === 0 && (
          <div className="text-center text-gray-400 mt-20">
            <i className="fas fa-comments text-6xl mb-4 text-pink-light"></i>
            <p className="text-lg">开始和AI小甜心聊天吧～</p>
            <p className="text-sm mt-2">她会用最温柔的方式哄你开心 💕</p>
          </div>
        )}

        {messages.map((msg, index) => (
          <div
            key={index}
            className={`chat-bubble flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div className={`max-w-[70%] ${msg.role === 'user' ? 'order-2' : 'order-1'}`}>
              <div
                className={`rounded-2xl px-5 py-3 ${
                  msg.role === 'user'
                    ? 'bg-gradient-to-r from-pink-medium to-pink-deep text-white'
                    : 'bg-gradient-to-r from-purple-soft to-pink-soft text-gray-800'
                }`}
              >
                <p className="whitespace-pre-wrap break-words">{msg.content}</p>
              </div>
              <p className={`text-xs text-gray-400 mt-1 ${msg.role === 'user' ? 'text-right' : 'text-left'}`}>
                {msg.timestamp}
              </p>
            </div>
            <div className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
              msg.role === 'user' ? 'bg-pink-deep ml-3 order-1' : 'bg-purple-light mr-3 order-2'
            }`}>
              <i className={`fas ${msg.role === 'user' ? 'fa-user' : 'fa-heart'} text-white`}></i>
            </div>
          </div>
        ))}

        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-purple-soft rounded-2xl px-5 py-3">
              <div className="typing-indicator flex space-x-2">
                <span className="w-2 h-2 bg-pink-deep rounded-full"></span>
                <span className="w-2 h-2 bg-pink-deep rounded-full"></span>
                <span className="w-2 h-2 bg-pink-deep rounded-full"></span>
              </div>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      <div className="p-6 bg-gradient-to-r from-pink-soft to-purple-soft">
        <div className="flex space-x-3">
          <textarea
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="说说你的心情吧... 💭"
            className="flex-1 rounded-2xl px-5 py-3 border-2 border-pink-light focus:border-pink-deep focus:outline-none resize-none bg-white/80 backdrop-blur-sm"
            rows="2"
            disabled={isLoading}
          />
          <button
            onClick={sendMessage}
            disabled={isLoading || !inputText.trim()}
            className="bg-gradient-to-r from-pink-medium to-pink-deep text-white px-8 py-3 rounded-2xl font-medium hover:shadow-lg transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed hover:scale-105"
          >
            <i className="fas fa-paper-plane mr-2"></i>
            发送吐槽
          </button>
        </div>
      </div>
    </div>
  );
}

export default ChatInterface;
