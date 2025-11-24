import React, { useState, useEffect } from 'react';
import ChatInterface from './components/ChatInterface';
import SettingsPanel from './components/SettingsPanel';
import FloatingHearts from './components/FloatingHearts';

function App() {
  const [showSettings, setShowSettings] = useState(false);
  const [config, setConfig] = useState({
    apiKey: '',
    modelId: '',
    chatHistory: []
  });

  useEffect(() => {
    const savedConfig = localStorage.getItem('coaxWifeConfig');
    if (savedConfig) {
      setConfig(JSON.parse(savedConfig));
    }
  }, []);

  const saveConfig = (newConfig) => {
    setConfig(newConfig);
    localStorage.setItem('coaxWifeConfig', JSON.stringify(newConfig));
  };

  return (
    <div className="min-h-screen relative overflow-hidden">
      <FloatingHearts />
      
      <div className="container mx-auto px-4 py-8 max-w-6xl relative z-10">
        <header className="text-center mb-8">
          <div className="inline-block animate-float">
            <h1 className="text-5xl font-bold text-pink-deep mb-2">
              <i className="fas fa-heart mr-3"></i>
              AI哄老婆系统
              <i className="fas fa-heart ml-3"></i>
            </h1>
          </div>
          <p className="text-purple-600 text-lg mt-4">
            用AI的温柔，传递你的爱意 💕
          </p>
        </header>

        <div className="flex justify-end mb-4">
          <button
            onClick={() => setShowSettings(!showSettings)}
            className="bg-white/80 backdrop-blur-sm px-6 py-3 rounded-full shadow-lg hover:shadow-xl transition-all duration-300 text-pink-deep font-medium hover:scale-105"
          >
            <i className="fas fa-cog mr-2"></i>
            {showSettings ? '关闭设置' : '系统设置'}
          </button>
        </div>

        {showSettings ? (
          <SettingsPanel config={config} onSave={saveConfig} />
        ) : (
          <ChatInterface config={config} />
        )}
      </div>
    </div>
  );
}

export default App;
