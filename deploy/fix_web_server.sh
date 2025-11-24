#!/bin/bash

# 修复Web服务器配置脚本
# 解决Apache占用80端口，切换到nginx的问题

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
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本: sudo $0"
        exit 1
    fi
}

# 检查服务状态
check_service_status() {
    local service_name=$1
    if systemctl is-active "$service_name" >/dev/null 2>&1; then
        echo "running"
    else
        echo "stopped"
    fi
}

# 停止Apache服务
stop_apache() {
    log_step "检查并停止Apache服务..."
    
    local apache_services=("httpd" "apache2")
    
    for service in "${apache_services[@]}"; do
        local status=$(check_service_status "$service")
        if [ "$status" = "running" ]; then
            log_info "发现运行中的Apache服务: $service"
            log_info "停止$service服务..."
            systemctl stop "$service"
            systemctl disable "$service"
            log_info "✓ $service服务已停止并禁用"
        fi
    done
}

# 检查端口占用
check_port_usage() {
    log_step "检查80端口占用情况..."
    
    local port_info=$(netstat -tlnp | grep :80 | head -1)
    if [ -n "$port_info" ]; then
        log_warn "80端口仍被占用:"
        echo "$port_info"
        
        # 尝试强制杀死占用80端口的进程
        local pid=$(netstat -tlnp | grep :80 | awk '{print $7}' | cut -d'/' -f1 | head -1)
        if [ -n "$pid" ] && [ "$pid" != "-" ]; then
            log_info "强制终止占用80端口的进程 (PID: $pid)..."
            kill -9 "$pid" 2>/dev/null || true
            sleep 2
        fi
    else
        log_info "✓ 80端口当前未被占用"
    fi
}

# 配置nginx
configure_nginx() {
    log_step "配置nginx..."
    
    local project_name="huangtangmin-system"
    local backend_dir="/var/www/$project_name/backend"
    local frontend_dir="/var/www/$project_name/frontend"
    local log_dir="/var/log/$project_name"
    
    # 确保日志目录存在
    mkdir -p "$log_dir"
    chown www-data:www-data "$log_dir"
    
    # 检查前端构建文件是否存在
    if [ ! -d "$frontend_dir/build" ]; then
        log_warn "前端构建文件不存在，尝试查找..."
        
        # 检查可能的构建输出目录
        for build_dir in "$frontend_dir/dist" "$frontend_dir/build"; do
            if [ -d "$build_dir" ]; then
                log_info "发现构建文件: $build_dir"
                if [ "$build_dir" != "$frontend_dir/build" ]; then
                    ln -sf "$build_dir" "$frontend_dir/build"
                    log_info "✓ 创建构建文件链接"
                fi
                break
            fi
        done
        
        if [ ! -d "$frontend_dir/build" ]; then
            log_error "未找到前端构建文件，请先运行构建"
            log_info "在部署目录执行: sudo ./02_deploy_project.sh"
            exit 1
        fi
    fi
    
    # 创建nginx配置文件
    log_info "创建nginx配置文件..."
    cat > "/etc/nginx/sites-available/$project_name" << EOF
server {
    listen 80;
    server_name _;
    
    # 日志配置
    access_log $log_dir/nginx_access.log;
    error_log $log_dir/nginx_error.log;
    
    # 前端静态文件
    location / {
        root $frontend_dir/build;
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
        
        # 支持WebSocket
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
    log_info "启用nginx站点配置..."
    if [ -f "/etc/nginx/sites-enabled/$project_name" ]; then
        rm -f "/etc/nginx/sites-enabled/$project_name"
    fi
    ln -s "/etc/nginx/sites-available/$project_name" "/etc/nginx/sites-enabled/"
    
    # 删除默认配置
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        rm -f "/etc/nginx/sites-enabled/default"
        log_info "✓ 已删除nginx默认配置"
    fi
    
    # 测试nginx配置
    log_info "测试nginx配置..."
    if nginx -t; then
        log_info "✓ nginx配置测试通过"
    else
        log_error "✗ nginx配置测试失败"
        exit 1
    fi
}

# 启动nginx服务
start_nginx() {
    log_step "启动nginx服务..."
    
    # 重新加载nginx配置
    systemctl daemon-reload
    
    # 启用并启动nginx
    systemctl enable nginx
    systemctl restart nginx
    
    # 等待服务启动
    sleep 3
    
    # 检查nginx状态
    if systemctl is-active nginx >/dev/null 2>&1; then
        log_info "✓ nginx服务启动成功"
    else
        log_error "✗ nginx服务启动失败"
        log_info "查看错误日志: journalctl -u nginx -f"
        exit 1
    fi
}

# 验证服务
verify_services() {
    log_step "验证服务状态..."
    
    local errors=0
    local project_name="huangtangmin-system"
    
    # 检查nginx
    if systemctl is-active nginx >/dev/null 2>&1; then
        log_info "✓ nginx服务运行正常"
        
        # 测试前端访问
        if curl -s http://127.0.0.1/ >/dev/null 2>&1; then
            log_info "✓ 前端页面可访问"
        else
            log_warn "△ 前端页面访问异常"
            ((errors++))
        fi
    else
        log_error "✗ nginx服务未运行"
        ((errors++))
    fi
    
    # 检查后端服务
    if systemctl is-active "$project_name-backend" >/dev/null 2>&1; then
        log_info "✓ 后端服务运行正常"
        
        # 测试后端API
        if curl -s http://127.0.0.1:3001/health >/dev/null 2>&1; then
            log_info "✓ 后端API响应正常"
        else
            log_warn "△ 后端API未响应（可能需要配置环境变量）"
        fi
    else
        log_warn "△ 后端服务状态未知"
    fi
    
    # 检查端口监听
    local nginx_port=$(netstat -tlnp | grep :80 | grep nginx)
    if [ -n "$nginx_port" ]; then
        log_info "✓ nginx正在监听80端口"
    else
        log_error "✗ nginx未监听80端口"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_info "✅ 所有服务验证通过！"
        return 0
    else
        log_error "❌ 发现 $errors 个问题"
        return 1
    fi
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "================================================================="
    echo "           Web服务器配置完成"
    echo "================================================================="
    echo ""
    echo "访问方式："
    echo "  🌐 前端应用:  http://$(curl -s ifconfig.me || echo "您的服务器IP")/"
    echo "  🔗 API接口:   http://$(curl -s ifconfig.me || echo "您的服务器IP")/api/"
    echo "  💖 应用名称:  哄汤敏系统"
    echo ""
    echo "服务状态："
    echo "  • nginx:     $(systemctl is-active nginx 2>/dev/null || echo "未知")"
    echo "  • 后端服务:   $(systemctl is-active huangtangmin-system-backend 2>/dev/null || echo "未知")"
    echo ""
    echo "常用命令："
    echo "  • 重启nginx:       systemctl restart nginx"
    echo "  • 查看nginx日志:    tail -f /var/log/huangtangmin-system/nginx_access.log"
    echo "  • 查看后端日志:     journalctl -u huangtangmin-system-backend -f"
    echo ""
    echo "================================================================="
    echo ""
}

# 主函数
main() {
    log_info "开始修复Web服务器配置..."
    
    check_root
    stop_apache
    check_port_usage
    configure_nginx
    start_nginx
    
    if verify_services; then
        show_access_info
        log_info "🎉 Web服务器配置修复完成！"
        log_info "现在可以通过浏览器访问您的应用了！"
    else
        log_error "修复过程中出现错误，请检查日志"
        exit 1
    fi
}

# 执行主函数
main "$@"
