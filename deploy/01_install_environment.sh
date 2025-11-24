#!/bin/bash

###############################################################################
# 阿里云Linux环境安装脚本
# 用途：安装Conda、Node.js、系统依赖等基础环境
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

# 检测系统版本
detect_system() {
    log_step "检测系统版本..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        log_info "检测到系统: $OS $VER"
    else
        log_error "无法检测系统版本"
        exit 1
    fi
    
    # 检查是否支持dnf
    if command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        log_info "使用包管理器: dnf"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        log_info "使用包管理器: yum"
    else
        log_error "未找到支持的包管理器 (dnf/yum)"
        exit 1
    fi
}

# 更新系统
update_system() {
    log_step "更新系统包..."
    $PKG_MANAGER update -y
    log_info "系统更新完成"
}

# 安装基础依赖
install_basic_deps() {
    log_step "安装基础开发工具和依赖..."
    
    # 安装开发工具组
    $PKG_MANAGER groupinstall -y "Development Tools"
    
    # 安装Python和系统依赖
    $PKG_MANAGER install -y \
        python3 \
        python3-devel \
        python3-pip \
        gcc \
        gcc-c++ \
        openssl-devel \
        libffi-devel \
        zlib-devel \
        bzip2-devel \
        readline-devel \
        sqlite-devel \
        wget \
        curl \
        git \
        vim \
        nginx \
        firewalld
    
    log_info "基础依赖安装完成"
}

# 创建用户和目录
setup_user_and_dirs() {
    log_step "创建部署用户和目录..."
    
    # 创建www-data用户（如果不存在）
    if ! id "www-data" &>/dev/null; then
        useradd -r -s /bin/false www-data
        log_info "创建用户 www-data"
    else
        log_info "用户 www-data 已存在"
    fi
    
    # 创建部署目录
    mkdir -p /var/www/huangtangmin-system/{backend,frontend}
    mkdir -p /var/log/huangtangmin-system
    
    # 设置目录权限
    chown -R www-data:www-data /var/www/huangtangmin-system
    chown -R www-data:www-data /var/log/huangtangmin-system
    chmod -R 755 /var/www/huangtangmin-system
    
    log_info "用户和目录创建完成"
}

# 安装Miniconda
install_miniconda() {
    log_step "安装Miniconda..."
    
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    INSTALL_DIR="/opt/miniconda3"
    
    # 如果已经安装则跳过
    if [ -d "$INSTALL_DIR" ]; then
        log_info "Miniconda已安装，跳过"
        return 0
    fi
    
    # 下载安装脚本
    cd /tmp
    wget -O miniconda.sh "$MINICONDA_URL"
    
    # 安装Miniconda
    bash miniconda.sh -b -p "$INSTALL_DIR"
    
    # 创建conda命令软链接
    ln -sf "$INSTALL_DIR/bin/conda" /usr/local/bin/conda
    ln -sf "$INSTALL_DIR/bin/python" /usr/local/bin/conda-python
    ln -sf "$INSTALL_DIR/bin/pip" /usr/local/bin/conda-pip
    
    # 初始化conda（为所有用户）
    "$INSTALL_DIR/bin/conda" init bash
    
    # 清理安装文件
    rm -f /tmp/miniconda.sh
    
    log_info "Miniconda安装完成"
}

# 安装Node.js
install_nodejs() {
    log_step "安装Node.js..."
    
    # 检查是否已安装
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node -v)
        log_info "Node.js已安装，版本: $node_version"
        return 0
    fi
    
    # 添加NodeSource仓库
    log_info "添加NodeSource仓库..."
    curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
    
    # 安装Node.js
    $PKG_MANAGER install -y nodejs
    
    # 验证安装
    local node_version=$(node -v)
    local npm_version=$(npm -v)
    
    log_info "Node.js安装完成"
    log_info "Node.js版本: $node_version"
    log_info "npm版本: $npm_version"
    
    # 配置npm镜像（提高下载速度）
    npm config set registry https://registry.npmmirror.com
    log_info "已配置npm淘宝镜像（npmmirror）"
}

# 配置防火墙
setup_firewall() {
    log_step "配置防火墙..."
    
    # 启动防火墙服务
    systemctl start firewalld
    systemctl enable firewalld
    
    # 开放必要端口
    firewall-cmd --permanent --add-port=22/tcp      # SSH
    firewall-cmd --permanent --add-port=80/tcp      # HTTP
    firewall-cmd --permanent --add-port=443/tcp     # HTTPS
    firewall-cmd --permanent --add-port=3001/tcp    # 后端API
    firewall-cmd --permanent --add-port=8520/tcp    # 前端开发服务器
    
    # 重载防火墙配置
    firewall-cmd --reload
    
    # 显示开放的端口
    log_info "防火墙配置完成，开放的端口："
    firewall-cmd --list-ports
}

# 配置nginx
setup_nginx() {
    log_step "配置nginx..."
    
    # 启动nginx服务
    systemctl start nginx
    systemctl enable nginx
    
    # 创建nginx配置目录
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled
    
    # 检查nginx配置
    nginx -t
    
    log_info "nginx配置完成"
}

# 创建环境变量配置文件
create_env_template() {
    log_step "创建环境变量模板..."
    
    # 后端环境变量模板
    cat > /var/www/huangtangmin-system/backend/.env << 'EOF'
# 服务配置
HOST=0.0.0.0
PORT=3001

# iFlow API配置
IFLOW_BASE_URL=https://apis.iflow.cn/v1
IFLOW_API_KEY=your_iflow_api_key_here
DEFAULT_MODEL=qwen3-vl-plus
DEFAULT_TEMPERATURE=0.8
DEFAULT_MAX_TOKENS=800

# RAG配置
CHROMA_DB_PATH=./data/chromadb
EMBEDDING_MODEL_NAME=sentence-transformers/all-MiniLM-L6-v2
RAG_TOP_K=5
RAG_SIMILARITY_THRESHOLD=0.7
EOF

    # 前端环境变量模板
    cat > /var/www/huangtangmin-system/frontend/.env << 'EOF'
# 前端配置
REACT_APP_API_URL=http://localhost:3001/api
NODE_ENV=production
HOST=0.0.0.0
PORT=3000
GENERATE_SOURCEMAP=false
EOF

    # 设置权限
    chown www-data:www-data /var/www/huangtangmin-system/backend/.env
    chown www-data:www-data /var/www/huangtangmin-system/frontend/.env
    chmod 640 /var/www/huangtangmin-system/backend/.env
    chmod 640 /var/www/huangtangmin-system/frontend/.env
    
    log_info "环境变量模板创建完成"
    log_warn "请编辑 /var/www/huangtangmin-system/backend/.env 设置正确的API密钥"
}

# 验证安装
verify_installation() {
    log_step "验证安装结果..."
    
    local errors=0
    
    # 检查Python
    if command -v python3 >/dev/null 2>&1; then
        log_info "✓ Python3: $(python3 --version)"
    else
        log_error "✗ Python3未安装"
        ((errors++))
    fi
    
    # 检查Conda
    if [ -f "/opt/miniconda3/bin/conda" ]; then
        log_info "✓ Conda: $(/opt/miniconda3/bin/conda --version)"
    else
        log_error "✗ Conda未安装"
        ((errors++))
    fi
    
    # 检查Node.js
    if command -v node >/dev/null 2>&1; then
        log_info "✓ Node.js: $(node -v)"
    else
        log_error "✗ Node.js未安装"
        ((errors++))
    fi
    
    # 检查npm
    if command -v npm >/dev/null 2>&1; then
        log_info "✓ npm: $(npm -v)"
    else
        log_error "✗ npm未安装"
        ((errors++))
    fi
    
    # 检查nginx
    if systemctl is-active nginx >/dev/null 2>&1; then
        log_info "✓ nginx服务运行中"
    else
        log_error "✗ nginx服务未运行"
        ((errors++))
    fi
    
    # 检查防火墙
    if systemctl is-active firewalld >/dev/null 2>&1; then
        log_info "✓ 防火墙服务运行中"
    else
        log_error "✗ 防火墙服务未运行"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_info "✓ 所有环境安装成功！"
        return 0
    else
        log_error "✗ 发现 $errors 个错误"
        return 1
    fi
}

# 显示安装信息
show_install_info() {
    echo ""
    echo "================================================================="
    echo "           哄汤敏系统 - 环境安装完成"
    echo "================================================================="
    echo ""
    echo "已安装的环境："
    echo "  • Python3:     $(python3 --version 2>/dev/null || echo '未安装')"
    echo "  • Miniconda:   $(/opt/miniconda3/bin/conda --version 2>/dev/null || echo '未安装')"
    echo "  • Node.js:     $(node -v 2>/dev/null || echo '未安装')"
    echo "  • npm:         $(npm -v 2>/dev/null || echo '未安装')"
    echo ""
    echo "部署目录："
    echo "  • 后端目录:    /var/www/huangtangmin-system/backend"
    echo "  • 前端目录:    /var/www/huangtangmin-system/frontend"
    echo "  • 日志目录:    /var/log/huangtangmin-system"
    echo ""
    echo "下一步操作："
    echo "  1. 编辑环境变量文件设置API密钥"
    echo "     sudo vim /var/www/huangtangmin-system/backend/.env"
    echo ""
    echo "  2. 运行项目部署脚本"
    echo "     sudo ./02_deploy_project.sh"
    echo ""
    echo "================================================================="
}

# 主函数
main() {
    log_info "开始安装哄汤敏系统环境..."
    
    check_root
    detect_system
    update_system
    install_basic_deps
    setup_user_and_dirs
    install_miniconda
    install_nodejs
    setup_firewall
    setup_nginx
    create_env_template
    
    if verify_installation; then
        show_install_info
        log_info "环境安装脚本执行完成！"
    else
        log_error "环境安装过程中出现错误，请检查日志"
        exit 1
    fi
}

# 执行主函数
main "$@"
