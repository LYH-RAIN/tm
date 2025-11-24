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
    
    # 检查当前目录是否包含项目文件
    if [ -f "../server/main.py" ] && [ -f "../src/App.js" ]; then
        log_info "检测到本地项目文件"
        
        # 复制后端代码
        log_info "复制后端代码..."
        cp -r ../server/* "$BACKEND_DIR/"
        
        # 复制前端代码
        log_info "复制前端代码..."
        cp -r ../src "$FRONTEND_DIR/"
        cp -r ../public "$FRONTEND_DIR/"
        cp ../package.json "$FRONTEND_DIR/"
        cp ../package-lock.json "$FRONTEND_DIR/" 2>/dev/null || true
        
        # 设置权限
        chown -R www-data:www-data "$DEPLOY_BASE"
        
    else
        log_warn "未在当前目录找到项目源码文件"
        log_info "请手动将项目代码复制到以下目录："
        echo "  后端代码 -> $BACKEND_DIR"
        echo "  前端代码 -> $FRONTEND_DIR"
        read -p "代码复制完成后按Enter继续..." -r
    fi
}

# 设置Python虚拟环境
setup_python_env() {
    log_step "设置Python虚拟环境..."
    
    cd "$BACKEND_DIR"
    
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
    
    # 安装依赖
    log_info "正在安装npm依赖..."
    npm install
    
    log_info "前端依赖安装完成"
}

# 构建前端应用
build_frontend() {
    log_step "构建前端应用..."
    
    cd "$FRONTEND_DIR"
    
    # 构建生产版本
    log_info "正在构建React应用..."
    npm run build
    
    if [ -d "build" ]; then
        log_info "前端构建完成"
    else
        log_error "前端构建失败"
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
