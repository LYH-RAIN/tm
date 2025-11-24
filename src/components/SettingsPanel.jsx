import React, { useState } from 'react';

function SettingsPanel({ config, onSave }) {
  const [modelId, setModelId] = useState(config.modelId || '');
  const [chatHistory, setChatHistory] = useState(config.chatHistory?.join('\n') || '');

  const handleSave = () => {
    const historyArray = chatHistory
      .split('\n')
      .filter(line => line.trim())
      .map(line => line.trim());

    onSave({
      modelId,
      chatHistory: historyArray
    });

    alert('设置已保存！💕');
  };

  return (
    <div className="bg-white/90 backdrop-blur-sm rounded-3xl shadow-2xl p-8">
      <h2 className="text-3xl font-bold text-pink-deep mb-6 flex items-center">
        <i className="fas fa-cog mr-3"></i>
        系统设置
      </h2>

      <div className="space-y-6">


        <div>
          <label className="block text-gray-700 font-medium mb-2">
            <i className="fas fa-brain mr-2 text-purple-600"></i>
            模型ID
          </label>
          <input
            type="text"
            value="qwen3-vl-plus"
            onChange={(e) => setModelId(e.target.value)}
            placeholder="例如: TBStars2-200B-A13B"
            className="w-full px-4 py-3 border-2 border-pink-light rounded-xl focus:border-pink-deep focus:outline-none bg-white/80"
          />
          <p className="text-sm text-gray-500 mt-2">
            选择合适的模型，推荐使用 TBStars2-200B-A13B
          </p>
        </div>

        <div>
          <label className="block text-gray-700 font-medium mb-2">
            <i className="fas fa-comments mr-2 text-pink-medium"></i>
            聊天记录样本（用于学习说话风格）
          </label>
          <textarea
            value={chatHistory}
            onChange={(e) => setChatHistory(e.target.value)}
            placeholder="每行一条聊天记录，例如：&#10;宝贝，今天开心吗？&#10;想你了，在干嘛呢～&#10;晚安啦，做个好梦💕"
            className="w-full px-4 py-3 border-2 border-pink-light rounded-xl focus:border-pink-deep focus:outline-none resize-none bg-white/80"
            rows="8"
          />
          <p className="text-sm text-gray-500 mt-2">
            输入你们平时的聊天记录，AI会学习这种说话风格
          </p>
        </div>

        <div className="flex justify-end space-x-4 pt-4">
          <button
            onClick={handleSave}
            className="bg-gradient-to-r from-pink-medium to-pink-deep text-white px-8 py-3 rounded-xl font-medium hover:shadow-lg transition-all duration-300 hover:scale-105"
          >
            <i className="fas fa-save mr-2"></i>
            保存设置
          </button>
        </div>
      </div>

      <div className="mt-8 p-6 bg-gradient-to-r from-pink-soft to-purple-soft rounded-2xl">
        <h3 className="font-bold text-pink-deep mb-3 flex items-center">
          <i className="fas fa-lightbulb mr-2"></i>
          使用提示
        </h3>
        <ul className="space-y-2 text-sm text-gray-700">
          <li className="flex items-start">
            <i className="fas fa-heart text-pink-medium mr-2 mt-1"></i>
            <span>API密钥已在后端配置，无需前端输入</span>
          </li>
          <li className="flex items-start">
            <i className="fas fa-heart text-pink-medium mr-2 mt-1"></i>
            <span>添加你们的聊天记录样本，让AI学习你的说话风格</span>
          </li>
          <li className="flex items-start">
            <i className="fas fa-heart text-pink-medium mr-2 mt-1"></i>
            <span>选择合适的模型后，就可以开始使用啦～</span>
          </li>
        </ul>
      </div>
    </div>
  );
}

export default SettingsPanel;
