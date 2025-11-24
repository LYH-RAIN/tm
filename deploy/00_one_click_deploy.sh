#!/bin/bash

###############################################################################
# 哄汤敏系统一键部署脚本
# 用途：在阿里云Linux上一键安装和部署完整的哄汤敏系统
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
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="huangtangmin-system"
VERSION="1.0.0"

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

log_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# 显示banner
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "================================================================="
    echo "                    哄汤敏系统 v${VERSION}"
    echo "                   一键部署脚本"
    echo "================================================================="
    echo -e "${NC}"
    echo ""
    echo "本脚本将在阿里云Linux上安装和部署完整的哄汤敏系统"
    echo ""
    echo "包含的功能："
    echo "  • 环境安装 (Conda, Node.js, 系统依赖)"
    echo "  • 项目部署 (FastAPI后端 + React前端)"
    echo "  • 服务配置 (systemd, nginx, 防火墙)"
    echo "  • 安全配置 (用户权限, SSL可选)"
    echo ""
    echo "预计部署时间: 10-15分钟"
    echo ""
    echo "================================================================="
    echo ""
}

# 显示使用帮助
show_help() {
    echo "使用方法:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --skip-env      跳过环境安装步骤"
    echo "  --skip-deploy   跳过项目部署步骤"
    echo "  --api-key KEY   设置iFlow API密钥"
    echo "  --domain DOMAIN 设置域名（用于SSL证书）"
    echo "  --ssl           安装SSL证书（需要--domain）"
    echo "  --backup        部署前备份现有系统"
    echo "  --verbose       显示详细输出"
    echo "  --quiet         静默模式"
    echo "  --help         显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                                    # 完整部署"
    echo "  $0 --api-key your_key --domain example.com --ssl"
    echo "  $0 --skip-env --verbose               # 跳过环境安装，详细模式"
    echo ""
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用root权限运行此脚本！"
        log_info "使用命令: sudo $0"
        exit 1
    fi
}

# 检查脚本文件是否存在
check_scripts() {
    local missing_scripts=()
    
    local required_scripts=(
        "01_install_environment.sh"
        "02_deploy_project.sh"
        "03_manage_services.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
            missing_scripts+=("$script")
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_error "缺少必要的脚本文件："
        for script in "${missing_scripts[@]}"; do
            echo "  - $script"
        done
        log_info "请确保所有脚本文件都在同一目录下"
        exit 1
    fi
}

# 检查系统要求
check_system_requirements() {
    log_header "检查系统要求..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测操作系统版本"
        exit 1
    fi
    
    source /etc/os-release
    log_info "检测到系统: $NAME $VERSION_ID"
    
    # 检查架构
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log_warn "检测到非x86_64架构: $arch，可能存在兼容性问题"
    fi
    
    # 检查内存
    local mem_gb=$(free -g | awk 'NR==2{print $2}')
    if [[ $mem_gb -lt 2 ]]; then
        log_warn "系统内存不足2GB (${mem_gb}GB)，可能影响运行性能"
    else
        log_info "系统内存: ${mem_gb}GB"
    fi
    
    # 检查磁盘空间
    local disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $disk_gb -lt 10 ]]; then
        log_error "磁盘空间不足10GB (可用: ${disk_gb}GB)"
        exit 1
    else
        log_info "可用磁盘空间: ${disk_gb}GB"
    fi
    
    # 检查网络连接
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "网络连接异常，无法访问外网"
        exit 1
    else
        log_info "网络连接正常"
    fi
    
    log_success "系统要求检查通过"
}

# 确认部署信息
confirm_deployment() {
    log_header "确认部署信息..."
    
    echo ""
    echo "部署配置:"
    echo "----------------------------------------"
    echo "项目名称:     $PROJECT_NAME"
    echo "部署目录:     /var/www/$PROJECT_NAME"
    echo "日志目录:     /var/log/$PROJECT_NAME"
    echo "服务用户:     www-data"
    echo "前端端口:     80 (nginx代理)"
    echo "后端端口:     3001 (内部)"
    echo "模型配置:     qwen3-vl-plus"
    
    if [[ -n "${API_KEY:-}" ]]; then
        echo "API密钥:      已设置"
    else
        echo "API密钥:      需要后续配置"
    fi
    
    if [[ -n "${DOMAIN:-}" ]]; then
        echo "域名:         $DOMAIN"
        if [[ "${INSTALL_SSL:-false}" == "true" ]]; then
            echo "SSL证书:      将自动安装"
        fi
    fi
    
    if [[ "${BACKUP:-false}" == "true" ]]; then
        echo "备份:         部署前备份现有系统"
    fi
    
    echo "----------------------------------------"
    echo ""
    
    read -p "确认开始部署? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "部署已取消"
        exit 0
    fi
}

# 执行备份
execute_backup() {
    if [[ "${BACKUP:-false}" == "true" ]]; then
        log_header "执行系统备份..."
        
        if [[ -f "$SCRIPT_DIR/03_manage_services.sh" ]]; then
            bash "$SCRIPT_DIR/03_manage_services.sh" backup
        else
            log_warn "未找到服务管理脚本，跳过备份"
        fi
    fi
}

# 安装环境
install_environment() {
    if [[ "${SKIP_ENV:-false}" == "true" ]]; then
        log_info "跳过环境安装步骤"
        return 0
    fi
    
    log_header "开始环境安装..."
    
    # 设置脚本权限
    chmod +x "$SCRIPT_DIR/01_install_environment.sh"
    
    # 执行环境安装脚本
    if bash "$SCRIPT_DIR/01_install_environment.sh"; then
        log_success "环境安装完成"
    else
        log_error "环境安装失败"
        exit 1
    fi
}

# 配置API密钥
configure_api_key() {
    if [[ -n "${API_KEY:-}" ]]; then
        log_step "配置API密钥..."
        
        local env_file="/var/www/$PROJECT_NAME/backend/.env"
        if [[ -f "$env_file" ]]; then
            # 更新API密钥
            sed -i "s/IFLOW_API_KEY=.*/IFLOW_API_KEY=$API_KEY/" "$env_file"
            log_info "API密钥已设置"
        else
            log_warn "环境变量文件不存在，将在部署后设置"
        fi
    fi
}

# 部署项目
deploy_project() {
    if [[ "${SKIP_DEPLOY:-false}" == "true" ]]; then
        log_info "跳过项目部署步骤"
        return 0
    fi
    
    log_header "开始项目部署..."
    
    # 配置API密钥（如果提前设置）
    configure_api_key
    
    # 设置脚本权限
    chmod +x "$SCRIPT_DIR/02_deploy_project.sh"
    
    # 执行项目部署脚本
    if bash "$SCRIPT_DIR/02_deploy_project.sh"; then
        log_success "项目部署完成"
    else
        log_error "项目部署失败"
        exit 1
    fi
    
    # 再次配置API密钥（确保生效）
    configure_api_key
}

# 安装SSL证书
install_ssl() {
    if [[ "${INSTALL_SSL:-false}" == "true" ]] && [[ -n "${DOMAIN:-}" ]]; then
        log_header "安装SSL证书..."
        
        # 安装certbot
        if ! command -v certbot >/dev/null 2>&1; then
            log_step "安装certbot..."
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y certbot python3-certbot-nginx
            elif command -v yum >/dev/null 2>&1; then
                yum install -y certbot python3-certbot-nginx
            else
                log_error "无法安装certbot，请手动安装"
                return 1
            fi
        fi
        
        # 申请SSL证书
        log_step "申请SSL证书..."
        if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "admin@$DOMAIN"; then
            log_success "SSL证书安装成功"
            
            # 设置自动续期
            (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
            log_info "已设置SSL证书自动续期"
        else
            log_warn "SSL证书安装失败，请检查域名解析"
        fi
    fi
}

# 后续配置
post_deployment() {
    log_header "执行后续配置..."
    
    # 设置服务管理脚本权限
    chmod +x "$SCRIPT_DIR/03_manage_services.sh"
    
    # 创建管理脚本软链接
    if [[ -f "$SCRIPT_DIR/03_manage_services.sh" ]]; then
        ln -sf "$SCRIPT_DIR/03_manage_services.sh" "/usr/local/bin/huangtangmin-service"
        log_info "已创建服务管理命令: huangtangmin-service"
    fi
    
    # 如果没有设置API密钥，提醒用户
    if [[ -z "${API_KEY:-}" ]]; then
        log_warn "请记得设置iFlow API密钥:"
        echo "  vim /var/www/$PROJECT_NAME/backend/.env"
        echo "  然后重启服务: huangtangmin-service restart"
    fi
    
    # 执行健康检查
    log_step "执行最终健康检查..."
    sleep 3
    if bash "$SCRIPT_DIR/03_manage_services.sh" health; then
        log_success "系统健康检查通过"
    else
        log_warn "系统健康检查发现问题，请查看详细输出"
    fi
}

# 显示部署完成信息
show_completion_info() {
    echo ""
    echo "================================================================="
    echo -e "${GREEN}            🎉 哄汤敏系统部署完成！ 🎉${NC}"
    echo "================================================================="
    echo ""
    echo "访问信息："
    
    if [[ -n "${DOMAIN:-}" ]]; then
        if [[ "${INSTALL_SSL:-false}" == "true" ]]; then
            echo "  🌐 网站地址:    https://$DOMAIN"
        else
            echo "  🌐 网站地址:    http://$DOMAIN"
        fi
    else
        echo "  🌐 网站地址:    http://您的服务器IP"
    fi
    
    echo "  📊 API接口:     http://您的服务器IP/api/"
    echo ""
    
    echo "管理命令："
    echo "  huangtangmin-service status     # 查看服务状态"
    echo "  huangtangmin-service restart    # 重启服务"
    echo "  huangtangmin-service logs       # 查看日志"
    echo "  huangtangmin-service health     # 健康检查"
    echo "  huangtangmin-service monitor    # 实时监控"
    echo ""
    
    echo "重要文件："
    echo "  📁 项目目录:    /var/www/$PROJECT_NAME"
    echo "  ⚙️ 环境配置:    /var/www/$PROJECT_NAME/backend/.env"
    echo "  📝 nginx配置:   /etc/nginx/sites-available/$PROJECT_NAME"
    echo "  📊 日志目录:    /var/log/$PROJECT_NAME"
    echo ""
    
    if [[ -z "${API_KEY:-}" ]]; then
        echo -e "${YELLOW}⚠️ 重要提醒：${NC}"
        echo "  请设置iFlow API密钥才能正常使用聊天功能："
        echo "  1. vim /var/www/$PROJECT_NAME/backend/.env"
        echo "  2. 修改 IFLOW_API_KEY=your_api_key_here"
        echo "  3. huangtangmin-service restart"
        echo ""
    fi
    
    echo "支持与帮助："
    echo "  📖 查看帮助:    huangtangmin-service --help"
    echo "  🔧 配置修改:    huangtangmin-service update-config"
    echo "  🗂️ 系统备份:    huangtangmin-service backup"
    echo ""
    
    echo "================================================================="
    echo -e "${GREEN}感谢使用哄汤敏系统！祝您使用愉快！💕${NC}"
    echo "================================================================="
}

# 错误处理
handle_error() {
    local exit_code=$?
    log_error "部署过程中发生错误 (退出码: $exit_code)"
    
    echo ""
    echo "故障排除建议："
    echo "1. 检查网络连接是否正常"
    echo "2. 确认系统满足最低要求"
    echo "3. 查看详细错误日志"
    echo "4. 尝试单独运行各个安装脚本进行调试"
    echo ""
    echo "如需帮助，请保存错误日志并联系技术支持"
    
    exit $exit_code
}

# 主函数
main() {
    # 设置错误处理
    trap handle_error ERR
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-env)
                SKIP_ENV=true
                shift
                ;;
            --skip-deploy)
                SKIP_DEPLOY=true
                shift
                ;;
            --api-key)
                API_KEY="$2"
                shift 2
                ;;
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --ssl)
                INSTALL_SSL=true
                shift
                ;;
            --backup)
                BACKUP=true
                shift
                ;;
            --verbose)
                set -x
                export VERBOSE=true
                shift
                ;;
            --quiet)
                export QUIET=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示banner
    show_banner
    
    # 检查环境
    check_root
    check_scripts
    check_system_requirements
    
    # 确认部署
    confirm_deployment
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 执行部署步骤
    execute_backup
    install_environment
    deploy_project
    install_ssl
    post_deployment
    
    # 计算部署时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    log_success "部署完成！总耗时: ${minutes}分${seconds}秒"
    
    # 显示完成信息
    show_completion_info
}

# 执行主函数
main "$@"
