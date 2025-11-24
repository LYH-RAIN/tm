#!/bin/bash

###############################################################################
# 哄汤敏系统项目部署脚本
# 用途：部署后端FastAPI和前端React应用
# 作者：哄汤敏系统部署脚本
# 版本：v1.0
###############################################################################

set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_NAME="huangtangmin-system"
DEPLOY_BASE="/var/www/$PROJECT_NAME"
BACKEND_DIR="$DEPLOY_BASE/backend"
FRONTEND_DIR="$DEPLOY_BASE/frontend"
LOG_DIR="/var/log/$PROJECT_NAME"
CONDA_PATH="/opt/miniconda3"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用root权限运行此脚本！"
        log_info "使用命令: sudo $0"
        exit 1
    fi
}

# 检查环境依赖
check_dependencies() {
    log_step "检查环境依赖..."
    
    local errors=0
    
    # 检查Python
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python3未安装"
        ((errors++))
    fi
    
    # 检查Conda
    if [ ! -f "$CONDA_PATH/bin/conda" ]; then
        log_error "Conda未安装"
        ((errors++))
    fi
    
    # 检查Node.js
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js未安装"
        ((errors++))
    fi
    
    # 检查部署目录
    if [ ! -d "$DEPLOY_BASE" ]; then
        log_error "部署目录不存在: $DEPLOY_BASE"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "发现 $errors 个环境问题，请先运行 01_install_environment.sh"
        exit 1
    fi
    
    log_info "环境依赖检查通过"
}

# 备份现有部署
backup_existing() {
    log_step "备份现有部署..."
    
    local backup_dir="/var/backups/$PROJECT_NAME/$(date +%Y%m%d_%H%M%S)"
    
    if [ -d "$BACKEND_DIR/app" ] || [ -d "$FRONTEND_DIR/src" ]; then
        mkdir -p "$backup_dir"
        
        if [ -d "$BACKEND_DIR/app" ]; then
            cp -r "$BACKEND_DIR" "$backup_dir/"
            log_info "已备份后端到: $backup_dir/backend"
        fi
        
        if [ -d "$FRONTEND_DIR/src" ]; then
            cp -r "$FRONTEND_DIR" "$backup_dir/"
            log_info "已备份前端到: $backup_dir/frontend"
        fi
    else
        log_info "未发现现有部署，跳过备份"
    fi
}

# 获取项目源码
get_source_code() {
    log_step "获取项目源码..."
    
    local source_found=false
    local git_repo_url=""

    # 方案1: 尝试从Git仓库克隆（如果提供了Git URL）
    if [[ -n "${GIT_REPO_URL:-}" ]]; then
        log_info "从Git仓库获取源码: $GIT_REPO_URL"

        if command -v git >/dev/null 2>&1; then
            local temp_dir="/tmp/huangtangmin-source-$(date +%s)"
            if git clone "$GIT_REPO_URL" "$temp_dir"; then
                log_info "Git克隆成功，正在复制文件..."

                # 复制后端代码
                if [ -d "$temp_dir/server" ]; then
                    cp -r "$temp_dir/server"/* "$BACKEND_DIR/"
                    log_info "✓ 后端代码已复制"
                fi

                # 复制前端代码
                if [ -d "$temp_dir/src" ] && [ -f "$temp_dir/package.json" ]; then
                    cp -r "$temp_dir/src" "$FRONTEND_DIR/"
                    cp -r "$temp_dir/public" "$FRONTEND_DIR/" 2>/dev/null || true
                    cp "$temp_dir/package.json" "$FRONTEND_DIR/"
                    cp "$temp_dir/package-lock.json" "$FRONTEND_DIR/" 2>/dev/null || true
                    cp "$temp_dir/webpack.config.js" "$FRONTEND_DIR/" 2>/dev/null || true
                    cp "$temp_dir/tailwind.config.js" "$FRONTEND_DIR/" 2>/dev/null || true
                    cp "$temp_dir/postcss.config.js" "$FRONTEND_DIR/" 2>/dev/null || true
                    cp "$temp_dir/index.html" "$FRONTEND_DIR/" 2>/dev/null || true
                    log_info "✓ 前端代码已复制"
                fi

                # 清理临时目录
                rm -rf "$temp_dir"
                source_found=true
            else
                log_warn "Git克隆失败，尝试其他方式..."
            fi
        else
            log_warn "Git未安装，无法从仓库克隆"
        fi
    fi

    # 方案2: 检查多个可能的本地源码路径
    if [[ "$source_found" == "false" ]]; then
        local search_paths=(
            ".."                    # 当前目录的上级
            "."                     # 当前目录
            "/opt/huangtangmin-src" # 预设的源码目录
            "$HOME/huangtangmin"    # 用户目录下
        )

        for search_path in "${search_paths[@]}"; do
            log_info "检查源码路径: $search_path"

            if [ -f "$search_path/server/main.py" ] || [ -f "$search_path/src/App.jsx" ] || [ -f "$search_path/src/App.js" ]; then
                log_info "✓ 在 $search_path 发现项目文件"

                # 复制后端代码
                if [ -d "$search_path/server" ]; then
                    log_info "复制后端代码..."
                    cp -r "$search_path/server"/* "$BACKEND_DIR/"
                    log_info "✓ 后端代码已复制"
                fi

                # 复制前端代码
                if [ -f "$search_path/package.json" ]; then
                    log_info "复制前端代码..."
                    [ -d "$search_path/src" ] && cp -r "$search_path/src" "$FRONTEND_DIR/"
                    [ -d "$search_path/public" ] && cp -r "$search_path/public" "$FRONTEND_DIR/"
                    cp "$search_path/package.json" "$FRONTEND_DIR/"
                    cp "$search_path/package-lock.json" "$FRONTEND_DIR/" 2>/dev/null || true
                    cp "$search_path/webpack.config.js" "$FRONTEND_DIR/" 2>/dev/null || true
                    cp "$search_path/tailwind.config.js" "$FRONTEND_DIR/" 2>/dev/null || true
                    cp "$search_path/postcss.config.js" "$FRONTEND_DIR/" 2>/dev/null || true
                    cp "$search_path/index.html" "$FRONTEND_DIR/" 2>/dev/null || true
                    log_info "✓ 前端代码已复制"
                fi

                source_found=true
                break
            fi
        done
    fi

    # 方案3: 如果仍未找到源码，尝试下载示例源码或提供指导
    if [[ "$source_found" == "false" ]]; then
        log_warn "未找到项目源码文件"
        log_info "请选择以下选项之一："
        echo "  1. 重新运行并指定Git仓库: $0 --git-url https://github.com/your-repo.git"
        echo "  2. 将源码放置到以下路径之一:"
        echo "     - /opt/huangtangmin-src/"
        echo "     - $HOME/huangtangmin/"
        echo "     - 当前目录的上级目录"
        echo "  3. 创建基础项目结构(用于测试)"
        echo ""

        read -p "是否创建基础项目结构用于测试部署? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            create_basic_project_structure
            source_found=true
        else
            log_error "无法获取项目源码，部署中断"
            log_info "请确保源码文件存在，然后重新运行部署脚本"
            exit 1
        fi
    fi

    # 设置权限
    if [[ "$source_found" == "true" ]]; then
        chown -R www-data:www-data "$DEPLOY_BASE"
        log_info "✓ 源码获取完成，权限已设置"
    fi
}

# 创建基础项目结构（用于测试部署）
create_basic_project_structure() {
    log_step "创建基础项目结构..."

    # 创建后端基础文件
    log_info "创建后端基础文件..."

    # main.py
    cat > "$BACKEND_DIR/main.py" << 'EOF'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import os

app = FastAPI(title="哄汤敏系统", version="1.0.0")

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    message: str
    modelId: str
    chatHistory: Optional[List[str]] = []

class ChatResponse(BaseModel):
    reply: str

@app.get("/")
async def root():
    return {"message": "哄汤敏系统后端运行中", "version": "1.0.0"}

@app.get("/health")
async def health():
    return {"status": "healthy", "message": "服务运行正常"}

@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        # 简单的回复逻辑（测试用）
        reply = f"亲爱的，我收到了你的消息：'{request.message}' 💕 不过目前API密钥还没配置好，请检查环境变量设置哦～"
        return ChatResponse(reply=reply)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"处理失败: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3001)
EOF

    # requirements.txt
    cat > "$BACKEND_DIR/requirements.txt" << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
gunicorn==21.2.0
python-multipart==0.0.6
pydantic==2.5.0
pydantic-settings==2.1.0
python-dotenv==1.0.0
openai==1.3.0
requests==2.31.0
aiofiles==23.2.0
jinja2==3.1.2
EOF

    # 创建前端基础文件
    log_info "创建前端基础文件..."

    # package.json
    cat > "$FRONTEND_DIR/package.json" << 'EOF'
{
  "name": "huangtangmin-system",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "axios": "^1.6.0",
    "web-vitals": "^3.5.0"
  },
  "scripts": {
    "start": "HOST=0.0.0.0 react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "proxy": "http://localhost:3001"
}
EOF

    # 创建 src 目录和基础文件
    mkdir -p "$FRONTEND_DIR/src"

    # App.js
    cat > "$FRONTEND_DIR/src/App.js" << 'EOF'
import React, { useState } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [messages, setMessages] = useState([]);
  const [inputText, setInputText] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const sendMessage = async () => {
    if (!inputText.trim() || isLoading) return;

    const userMessage = {
      role: 'user',
      content: inputText,
      timestamp: new Date().toLocaleTimeString()
    };

    setMessages(prev => [...prev, userMessage]);
    setInputText('');
    setIsLoading(true);

    try {
      const response = await axios.post('/api/chat', {
        message: inputText,
        modelId: 'qwen3-vl-plus',
        chatHistory: []
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
        content: '抱歉宝贝，系统出现了一点问题 💕',
        timestamp: new Date().toLocaleTimeString()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="App">
      <div className="chat-container">
        <div className="chat-header">
          <h1>💕 哄汤敏系统 💕</h1>
          <p>你的专属AI小甜心～</p>
        </div>

        <div className="chat-messages">
          {messages.map((msg, index) => (
            <div key={index} className={`message ${msg.role}`}>
              <div className="message-content">{msg.content}</div>
              <div className="message-time">{msg.timestamp}</div>
            </div>
          ))}
          {isLoading && <div className="loading">AI小甜心正在思考中...</div>}
        </div>

        <div className="chat-input">
          <input
            type="text"
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
            placeholder="告诉我你的心情吧～"
            disabled={isLoading}
          />
          <button onClick={sendMessage} disabled={isLoading || !inputText.trim()}>
            发送💕
          </button>
        </div>
      </div>
    </div>
  );
}

export default App;
EOF

    # App.css
    cat > "$FRONTEND_DIR/src/App.css" << 'EOF'
.App {
  text-align: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  font-size: calc(10px + 2vmin);
  color: white;
}

.chat-container {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 20px;
  padding: 20px;
  width: 90%;
  max-width: 800px;
  height: 80vh;
  display: flex;
  flex-direction: column;
}

.chat-header {
  margin-bottom: 20px;
}

.chat-header h1 {
  margin: 0;
  font-size: 2.5rem;
}

.chat-header p {
  margin: 10px 0;
  font-size: 1.2rem;
  opacity: 0.8;
}

.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
  margin-bottom: 20px;
}

.message {
  margin: 10px 0;
  padding: 10px;
  border-radius: 15px;
  max-width: 70%;
}

.message.user {
  background: rgba(255, 105, 180, 0.3);
  margin-left: auto;
  text-align: right;
}

.message.assistant {
  background: rgba(255, 255, 255, 0.2);
  margin-right: auto;
  text-align: left;
}

.message-content {
  font-size: 1rem;
  margin-bottom: 5px;
}

.message-time {
  font-size: 0.7rem;
  opacity: 0.7;
}

.loading {
  text-align: center;
  font-style: italic;
  opacity: 0.7;
}

.chat-input {
  display: flex;
  gap: 10px;
}

.chat-input input {
  flex: 1;
  padding: 15px;
  border: none;
  border-radius: 25px;
  font-size: 1rem;
  outline: none;
}

.chat-input button {
  padding: 15px 25px;
  border: none;
  border-radius: 25px;
  background: linear-gradient(45deg, #ff6b6b, #feca57);
  color: white;
  font-size: 1rem;
  cursor: pointer;
  transition: transform 0.2s;
}

.chat-input button:hover:not(:disabled) {
  transform: scale(1.05);
}

.chat-input button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
EOF

    # index.js
    cat > "$FRONTEND_DIR/src/index.js" << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

    # index.css
    cat > "$FRONTEND_DIR/src/index.css" << 'EOF'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
EOF

    # 创建 public 目录和基础文件
    mkdir -p "$FRONTEND_DIR/public"

    # index.html
    cat > "$FRONTEND_DIR/public/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="哄汤敏系统 - 你的专属AI小甜心" />
    <title>💕 哄汤敏系统 💕</title>
  </head>
  <body>
    <noscript>你需要启用JavaScript才能运行这个应用。</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

    # manifest.json
    cat > "$FRONTEND_DIR/public/manifest.json" << 'EOF'
{
  "short_name": "哄汤敏系统",
  "name": "哄汤敏系统 - AI小甜心",
  "icons": [],
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
EOF

    log_info "✓ 基础项目结构创建完成"
}

# 设置Python虚拟环境
setup_python_env() {
    log_step "设置Python虚拟环境..."
    
    cd "$BACKEND_DIR"
    
    # 接受Conda服务条款
    log_info "接受Conda服务条款..."
    "$CONDA_PATH/bin/conda" config --set tos_consent true 2>/dev/null || true

    # 如果上面的方法不行，使用新的tos accept命令
    "$CONDA_PATH/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true
    "$CONDA_PATH/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true

    # 使用Conda创建虚拟环境
    if [ ! -d "$BACKEND_DIR/conda_env" ]; then
        log_info "创建Conda虚拟环境..."
        "$CONDA_PATH/bin/conda" create -p "$BACKEND_DIR/conda_env" python=3.9 -y
    else
        log_info "Conda虚拟环境已存在"
    fi
    
    # 激活虚拟环境并安装依赖
    source "$CONDA_PATH/etc/profile.d/conda.sh"
    conda activate "$BACKEND_DIR/conda_env"
    
    # 安装核心依赖
    log_info "安装Python依赖..."
    pip install -U pip
    
    # 检查requirements.txt是否存在，如果不存在则创建
    if [ ! -f "requirements.txt" ]; then
        log_info "创建requirements.txt..."
        cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
gunicorn==21.2.0
python-multipart==0.0.6
pydantic==2.5.0
pydantic-settings==2.1.0
python-dotenv==1.0.0
openai==1.3.0
requests==2.31.0
aiofiles==23.2.0
jinja2==3.1.2
EOF
    fi
    
    pip install -r requirements.txt
    
    # 安装可选的RAG依赖（如果需要）
    log_info "安装RAG相关依赖（可选）..."
    pip install sentence-transformers chromadb || log_warn "RAG依赖安装失败，将跳过RAG功能"
    
    conda deactivate
    
    log_info "Python环境设置完成"
}

# 安装前端依赖
install_frontend_deps() {
    log_step "安装前端依赖..."
    
    cd "$FRONTEND_DIR"
    
    # 检查package.json是否存在
    if [ ! -f "package.json" ]; then
        log_error "未找到package.json文件"
        exit 1
    fi
    
    # 强制重新安装依赖以确保完整性
    if [ -d "node_modules" ]; then
        log_info "清理现有node_modules目录..."
        rm -rf node_modules package-lock.json
    fi

    # 安装依赖
    log_info "正在安装npm依赖..."

    # 清理npm缓存
    log_info "清理npm缓存..."
    npm cache clean --force 2>/dev/null || true

    # 检查磁盘空间
    local disk_free=$(df /tmp | awk 'NR==2{print $4}')
    if [[ $disk_free -lt 1048576 ]]; then  # 小于1GB
        log_warn "磁盘空间可能不足，当前可用空间: $(( $disk_free / 1024 ))MB"
    fi

    # 设置npm配置和镜像源
    npm config set fetch-retries 3
    npm config set fetch-retry-factor 2
    npm config set fetch-timeout 60000
    npm config set maxsockets 1
    npm config set registry https://registry.npmmirror.com

    # 首先安装package.json中的所有依赖
    log_info "安装package.json中的所有依赖..."

    # 优先使用cnpm（如果可用）
    if command -v cnpm >/dev/null 2>&1; then
        log_info "使用cnpm安装所有依赖（更快）..."
        if cnpm install --silent; then
            log_info "✓ cnmp安装所有依赖成功"
        else
            log_warn "cnpm安装失败，回退到npm"
            npm install --no-audit --progress=false
        fi
    else
        # npm安装重试机制
        local max_attempts=3
        local attempt=1

        while [[ $attempt -le $max_attempts ]]; do
            log_info "第 $attempt 次尝试npm安装依赖..."

            if npm install --no-audit --progress=false; then
                log_info "✓ npm依赖安装成功"
                break
            else
                log_warn "第 $attempt 次安装失败"
                attempt=$((attempt + 1))

                if [[ $attempt -le $max_attempts ]]; then
                    log_info "清理缓存后重试..."
                    npm cache clean --force
                    sleep 3
                else
                    log_error "npm依赖安装失败，已尝试 $max_attempts 次"
                    log_info "请尝试手动执行以下命令进行问题排查："
                    echo "  cd $FRONTEND_DIR"
                    echo "  npm cache clean --force"
                    echo "  npm install --verbose"
                    exit 1
                fi
            fi
        done
    fi

    # 验证关键依赖是否已安装
    log_info "验证关键运行时依赖..."
    local missing_deps=()
    local critical_deps=("react" "react-dom" "axios" "tailwindcss" "autoprefixer" "postcss")

    for dep in "${critical_deps[@]}"; do
        if ! npm list "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    # 如果有缺失的关键依赖，单独安装
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warn "检测到缺失的关键依赖: ${missing_deps[*]}"
        log_info "单独安装缺失的关键依赖..."

        for dep in "${missing_deps[@]}"; do
            log_info "安装 $dep..."
            if command -v cnpm >/dev/null 2>&1; then
                cnpm install "$dep" --save
            else
                npm install "$dep" --save --no-audit
            fi
        done

        log_info "✓ 关键依赖补全完成"
    else
        log_info "✓ 所有关键依赖验证通过"
    fi

    log_info "前端依赖安装完成"
}

# 构建前端应用
build_frontend() {
    log_step "构建前端应用..."
    
    cd "$FRONTEND_DIR"
    
    # 检查并安装webpack相关依赖（如果需要）
    local build_script=$(node -p "JSON.parse(require('fs').readFileSync('package.json')).scripts.build" 2>/dev/null || echo "")

    if [[ "$build_script" == *"webpack"* ]]; then
        log_info "检测到使用webpack构建，确保webpack相关依赖已安装..."

        # 检查webpack是否已安装
        if ! npm list webpack >/dev/null 2>&1; then
            log_info "webpack未安装，尝试快速安装..."

            # 方案1: 尝试使用cnpm（如果已安装）
            if command -v cnpm >/dev/null 2>&1; then
                log_info "检测到cnpm，使用cnpm安装webpack完整依赖..."
                if cnpm install --save-dev webpack webpack-cli html-webpack-plugin babel-loader @babel/core @babel/preset-react @babel/preset-env style-loader css-loader postcss-loader; then
                    log_info "✓ cnpm安装webpack完整依赖成功"
                else
                    log_warn "cnpm安装失败，跳过webpack安装"
                fi
            # 方案2: 快速npm安装（60秒超时，安装更多依赖）
            elif timeout 60 npm install --save-dev --no-audit --progress=false webpack webpack-cli html-webpack-plugin babel-loader @babel/core @babel/preset-react @babel/preset-env style-loader css-loader postcss-loader >/dev/null 2>&1; then
                log_info "✓ npm快速安装webpack完整依赖成功"
            else
                log_warn "webpack完整依赖安装超时，尝试基础安装..."
                # 降级方案：只安装核心依赖
                if timeout 30 npm install --save-dev --no-audit --progress=false webpack webpack-cli html-webpack-plugin >/dev/null 2>&1; then
                    log_info "✓ npm安装webpack核心依赖成功"
                else
                    log_warn "webpack依赖安装失败，跳过安装步骤"
                    log_info "将直接尝试使用npx webpack构建"
                fi
            fi
        fi

        # 使用npx调用本地webpack
        if [[ "$build_script" == "webpack --mode production" ]] || [ -f "webpack.config.js" ]; then
            log_info "使用npx webpack构建..."
            if [ -f "webpack.config.js" ]; then
                npx webpack --config webpack.config.js --mode production
            else
                npx webpack --mode production
            fi
        else
            log_info "正在构建React应用..."
            npm run build
        fi
    else
        # 构建生产版本
        log_info "正在构建React应用..."
        npm run build
    fi

    # 检查构建结果
    if [ -d "build" ] || [ -d "dist" ]; then
        # 如果是webpack构建，可能输出目录是dist
        if [ -d "dist" ] && [ ! -d "build" ]; then
            log_info "检测到webpack输出目录为dist，创建build目录链接..."
            ln -sf dist build
        fi
        log_info "前端构建完成"
    else
        log_error "前端构建失败，未找到构建输出目录"
        log_info "请检查构建配置或手动执行构建命令"
        exit 1
    fi
}

# 配置nginx
configure_nginx() {
    log_step "配置nginx..."
    
    # 创建nginx配置文件
    cat > "/etc/nginx/sites-available/$PROJECT_NAME" << EOF
server {
    listen 80;
    server_name _;
    
    # 日志配置
    access_log $LOG_DIR/nginx_access.log;
    error_log $LOG_DIR/nginx_error.log;
    
    # 前端静态文件
    location / {
        root $FRONTEND_DIR/build;
        try_files \$uri \$uri/ /index.html;
        
        # 缓存静态资源
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # API代理到后端
    location /api/ {
        proxy_pass http://127.0.0.1:3001/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # 支持WebSocket（如果需要）
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # 健康检查
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # 启用站点配置
    if [ -f "/etc/nginx/sites-enabled/$PROJECT_NAME" ]; then
        rm -f "/etc/nginx/sites-enabled/$PROJECT_NAME"
    fi
    ln -s "/etc/nginx/sites-available/$PROJECT_NAME" "/etc/nginx/sites-enabled/"
    
    # 删除默认配置（如果存在）
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        rm -f "/etc/nginx/sites-enabled/default"
    fi
    
    # 测试nginx配置
    nginx -t
    
    # 重新加载nginx
    systemctl reload nginx
    
    log_info "nginx配置完成"
}

# 创建systemd服务
create_systemd_services() {
    log_step "创建systemd服务..."
    
    # 后端服务配置
    cat > "/etc/systemd/system/$PROJECT_NAME-backend.service" << EOF
[Unit]
Description=哄汤敏系统后端服务
After=network.target
Wants=network.target

[Service]
Type=exec
User=www-data
Group=www-data
WorkingDirectory=$BACKEND_DIR
Environment=PATH=$BACKEND_DIR/conda_env/bin
EnvironmentFile=$BACKEND_DIR/.env
ExecStart=$BACKEND_DIR/conda_env/bin/gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker -b 127.0.0.1:3001
Restart=always
RestartSec=3
StartLimitInterval=60s
StartLimitBurst=3

# 日志配置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$PROJECT_NAME-backend

# 安全配置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$BACKEND_DIR $LOG_DIR

[Install]
WantedBy=multi-user.target
EOF

    log_info "systemd服务创建完成"
}

# 设置日志轮转
setup_log_rotation() {
    log_step "设置日志轮转..."
    
    # 创建logrotate配置
    cat > "/etc/logrotate.d/$PROJECT_NAME" << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 www-data www-data
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
        systemctl reload $PROJECT_NAME-backend > /dev/null 2>&1 || true
    endscript
}
EOF

    log_info "日志轮转配置完成"
}

# 启动服务
start_services() {
    log_step "启动服务..."
    
    # 重新加载systemd配置
    systemctl daemon-reload
    
    # 启用并启动后端服务
    systemctl enable "$PROJECT_NAME-backend"
    systemctl start "$PROJECT_NAME-backend"
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if systemctl is-active "$PROJECT_NAME-backend" >/dev/null 2>&1; then
        log_info "✓ 后端服务启动成功"
    else
        log_error "✗ 后端服务启动失败"
        log_info "查看服务日志: journalctl -u $PROJECT_NAME-backend -f"
        exit 1
    fi
    
    # 重新启动nginx
    systemctl restart nginx
    
    if systemctl is-active nginx >/dev/null 2>&1; then
        log_info "✓ nginx服务运行正常"
    else
        log_error "✗ nginx服务异常"
        exit 1
    fi
}

# 验证部署
verify_deployment() {
    log_step "验证部署..."
    
    local errors=0
    
    # 检查后端服务
    if systemctl is-active "$PROJECT_NAME-backend" >/dev/null 2>&1; then
        log_info "✓ 后端服务运行中"
        
        # 测试后端API
        if curl -s http://127.0.0.1:3001/health >/dev/null 2>&1; then
            log_info "✓ 后端API响应正常"
        else
            log_warn "△ 后端API未响应（可能需要配置API密钥）"
        fi
    else
        log_error "✗ 后端服务未运行"
        ((errors++))
    fi
    
    # 检查nginx服务
    if systemctl is-active nginx >/dev/null 2>&1; then
        log_info "✓ nginx服务运行中"
        
        # 测试前端访问
        if curl -s http://127.0.0.1/ >/dev/null 2>&1; then
            log_info "✓ 前端页面可访问"
        else
            log_error "✗ 前端页面无法访问"
            ((errors++))
        fi
    else
        log_error "✗ nginx服务未运行"
        ((errors++))
    fi
    
    # 检查日志目录权限
    if [ -w "$LOG_DIR" ]; then
        log_info "✓ 日志目录权限正常"
    else
        log_error "✗ 日志目录权限异常"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_info "✓ 部署验证成功！"
        return 0
    else
        log_error "✗ 发现 $errors 个问题"
        return 1
    fi
}

# 显示部署信息
show_deploy_info() {
    echo ""
    echo "================================================================="
    echo "           哄汤敏系统 - 部署完成"
    echo "================================================================="
    echo ""
    echo "服务信息："
    echo "  • 后端服务:    $PROJECT_NAME-backend"
    echo "  • 前端访问:    http://您的服务器IP/"
    echo "  • API地址:     http://您的服务器IP/api/"
    echo ""
    echo "目录结构："
    echo "  • 后端目录:    $BACKEND_DIR"
    echo "  • 前端目录:    $FRONTEND_DIR"
    echo "  • 日志目录:    $LOG_DIR"
    echo "  • 备份目录:    /var/backups/$PROJECT_NAME/"
    echo ""
    echo "常用命令："
    echo "  • 查看后端状态:  systemctl status $PROJECT_NAME-backend"
    echo "  • 查看后端日志:  journalctl -u $PROJECT_NAME-backend -f"
    echo "  • 重启后端:      systemctl restart $PROJECT_NAME-backend"
    echo "  • 重启nginx:     systemctl restart nginx"
    echo ""
    echo "配置文件："
    echo "  • 后端环境变量:  $BACKEND_DIR/.env"
    echo "  • nginx配置:     /etc/nginx/sites-available/$PROJECT_NAME"
    echo ""
    echo "重要提醒："
    echo "  1. 请确保在 $BACKEND_DIR/.env 中设置正确的IFLOW_API_KEY"
    echo "  2. 如需SSL证书，请运行: certbot --nginx -d 您的域名"
    echo "  3. 定期检查日志和备份数据"
    echo ""
    echo "================================================================="
}

# 主函数
main() {
    log_info "开始部署哄汤敏系统..."
    
    check_root
    check_dependencies
    backup_existing
    get_source_code
    setup_python_env
    install_frontend_deps
    build_frontend
    configure_nginx
    create_systemd_services
    setup_log_rotation
    start_services
    
    if verify_deployment; then
        show_deploy_info
        log_info "项目部署脚本执行完成！"
    else
        log_error "部署过程中出现错误，请检查日志"
        exit 1
    fi
}

# 执行主函数
main "$@"
