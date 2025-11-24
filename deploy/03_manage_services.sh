#!/bin/bash

###############################################################################
# 哄汤敏系统服务管理脚本
# 用途：管理后端服务的启动、停止、重启、状态查看等操作
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
NC='\033[0m' # No Color

# 配置变量
PROJECT_NAME="huangtangmin-system"
BACKEND_SERVICE="$PROJECT_NAME-backend"
LOG_DIR="/var/log/$PROJECT_NAME"
DEPLOY_BASE="/var/www/$PROJECT_NAME"

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

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用root权限运行此脚本！"
        log_info "使用命令: sudo $0"
        exit 1
    fi
}

# 显示使用帮助
show_help() {
    echo "================================================================="
    echo "          哄汤敏系统 - 服务管理脚本"
    echo "================================================================="
    echo ""
    echo "用法: $0 [选项] [命令]"
    echo ""
    echo "命令："
    echo "  start         启动所有服务"
    echo "  stop          停止所有服务"
    echo "  restart       重启所有服务"
    echo "  status        查看服务状态"
    echo "  logs          查看服务日志"
    echo "  health        健康检查"
    echo "  reload        重新加载配置"
    echo "  backup        备份当前部署"
    echo "  monitor       实时监控服务状态"
    echo "  update-config 更新配置文件"
    echo "  cleanup       清理旧日志和缓存"
    echo ""
    echo "选项："
    echo "  -h, --help    显示此帮助信息"
    echo "  -v, --verbose 显示详细信息"
    echo "  -q, --quiet   静默模式"
    echo ""
    echo "示例："
    echo "  $0 start                # 启动所有服务"
    echo "  $0 status               # 查看服务状态"
    echo "  $0 logs -f              # 实时查看日志"
    echo "  $0 restart --verbose    # 详细模式重启服务"
    echo ""
    echo "================================================================="
}

# 检查服务状态
check_service_status() {
    local service=$1
    if systemctl is-active "$service" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 获取服务状态文本
get_service_status_text() {
    local service=$1
    if check_service_status "$service"; then
        echo -e "${GREEN}运行中${NC}"
    else
        echo -e "${RED}已停止${NC}"
    fi
}

# 启动服务
start_services() {
    log_header "启动所有服务..."
    
    # 启动后端服务
    log_step "启动后端服务..."
    if check_service_status "$BACKEND_SERVICE"; then
        log_info "后端服务已在运行"
    else
        systemctl start "$BACKEND_SERVICE"
        sleep 2
        if check_service_status "$BACKEND_SERVICE"; then
            log_info "✓ 后端服务启动成功"
        else
            log_error "✗ 后端服务启动失败"
            return 1
        fi
    fi
    
    # 启动nginx
    log_step "启动nginx服务..."
    if check_service_status "nginx"; then
        log_info "nginx服务已在运行"
    else
        systemctl start nginx
        sleep 1
        if check_service_status "nginx"; then
            log_info "✓ nginx服务启动成功"
        else
            log_error "✗ nginx服务启动失败"
            return 1
        fi
    fi
    
    # 健康检查
    log_step "执行健康检查..."
    health_check
}

# 停止服务
stop_services() {
    log_header "停止所有服务..."
    
    # 停止后端服务
    log_step "停止后端服务..."
    if check_service_status "$BACKEND_SERVICE"; then
        systemctl stop "$BACKEND_SERVICE"
        sleep 2
        if ! check_service_status "$BACKEND_SERVICE"; then
            log_info "✓ 后端服务停止成功"
        else
            log_error "✗ 后端服务停止失败"
            return 1
        fi
    else
        log_info "后端服务已停止"
    fi
    
    log_info "服务停止完成"
}

# 重启服务
restart_services() {
    log_header "重启所有服务..."
    
    # 重启后端服务
    log_step "重启后端服务..."
    systemctl restart "$BACKEND_SERVICE"
    sleep 3
    
    # 重新加载nginx
    log_step "重新加载nginx配置..."
    systemctl reload nginx
    sleep 1
    
    # 验证服务状态
    if check_service_status "$BACKEND_SERVICE" && check_service_status "nginx"; then
        log_info "✓ 所有服务重启成功"
        
        # 健康检查
        sleep 2
        health_check
    else
        log_error "✗ 服务重启失败"
        show_status
        return 1
    fi
}

# 显示服务状态
show_status() {
    log_header "服务状态信息..."
    
    echo ""
    echo "┌─────────────────────┬──────────────┬────────────────────┐"
    echo "│ 服务名称            │ 状态         │ 端口/说明          │"
    echo "├─────────────────────┼──────────────┼────────────────────┤"
    echo -e "│ 后端服务            │ $(get_service_status_text "$BACKEND_SERVICE") │ 127.0.0.1:3001    │"
    echo -e "│ nginx代理           │ $(get_service_status_text "nginx")     │ 0.0.0.0:80         │"
    echo -e "│ 防火墙              │ $(get_service_status_text "firewalld") │ 端口管理           │"
    echo "└─────────────────────┴──────────────┴────────────────────┘"
    echo ""
    
    # 显示详细信息
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo "详细服务状态："
        echo "----------------------------------------"
        
        # 后端服务详情
        echo "后端服务 ($BACKEND_SERVICE)："
        systemctl status "$BACKEND_SERVICE" --no-pager -l || true
        echo ""
        
        # nginx服务详情
        echo "nginx服务："
        systemctl status nginx --no-pager -l || true
        echo ""
        
        # 端口占用情况
        echo "端口占用情况："
        netstat -tlnp | grep -E ":80|:3001|:443" || echo "未找到相关端口占用"
        echo ""
        
        # 磁盘空间
        echo "磁盘空间："
        df -h | grep -E "/$|/var"
        echo ""
    fi
}

# 查看日志
view_logs() {
    local follow_flag=""
    local service=""
    local lines=50
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--follow)
                follow_flag="-f"
                shift
                ;;
            -n|--lines)
                lines="$2"
                shift 2
                ;;
            backend|nginx|all)
                service="$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    log_header "查看服务日志..."
    
    if [[ -z "$service" ]] || [[ "$service" == "all" ]]; then
        log_info "查看所有服务日志（最近${lines}行）"
        echo ""
        echo "=== 后端服务日志 ==="
        journalctl -u "$BACKEND_SERVICE" -n "$lines" --no-pager $follow_flag &
        
        if [[ "$follow_flag" == "-f" ]]; then
            log_info "按Ctrl+C退出日志跟踪模式"
            wait
        fi
    elif [[ "$service" == "backend" ]]; then
        log_info "查看后端服务日志"
        journalctl -u "$BACKEND_SERVICE" -n "$lines" --no-pager $follow_flag
    elif [[ "$service" == "nginx" ]]; then
        log_info "查看nginx日志"
        if [[ -f "$LOG_DIR/nginx_access.log" ]]; then
            tail -n "$lines" "$LOG_DIR/nginx_access.log" $follow_flag
        else
            journalctl -u nginx -n "$lines" --no-pager $follow_flag
        fi
    fi
}

# 健康检查
health_check() {
    log_header "执行健康检查..."
    
    local errors=0
    
    # 检查后端服务
    if check_service_status "$BACKEND_SERVICE"; then
        log_info "✓ 后端服务运行正常"
        
        # 检查后端API
        if curl -s -f http://127.0.0.1:3001/health >/dev/null 2>&1; then
            log_info "✓ 后端API健康检查通过"
        else
            log_warn "△ 后端API健康检查失败（可能需要配置API密钥）"
        fi
    else
        log_error "✗ 后端服务未运行"
        ((errors++))
    fi
    
    # 检查nginx服务
    if check_service_status "nginx"; then
        log_info "✓ nginx服务运行正常"
        
        # 检查前端访问
        if curl -s -f http://127.0.0.1/ >/dev/null 2>&1; then
            log_info "✓ 前端页面访问正常"
        else
            log_warn "△ 前端页面访问异常"
            ((errors++))
        fi
    else
        log_error "✗ nginx服务未运行"
        ((errors++))
    fi
    
    # 检查磁盘空间
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 90 ]]; then
        log_info "✓ 磁盘空间充足 (${disk_usage}%)"
    else
        log_warn "△ 磁盘空间不足 (${disk_usage}%)"
        ((errors++))
    fi
    
    # 检查内存使用
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [[ $mem_usage -lt 90 ]]; then
        log_info "✓ 内存使用正常 (${mem_usage}%)"
    else
        log_warn "△ 内存使用过高 (${mem_usage}%)"
        ((errors++))
    fi
    
    # 检查网络连接
    if curl -s --connect-timeout 5 https://apis.iflow.cn >/dev/null 2>&1; then
        log_info "✓ iFlow API网络连接正常"
    else
        log_warn "△ iFlow API网络连接异常"
        ((errors++))
    fi
    
    echo ""
    if [[ $errors -eq 0 ]]; then
        log_info "🎉 健康检查全部通过！"
    elif [[ $errors -le 2 ]]; then
        log_warn "⚠️ 发现 $errors 个警告，系统基本正常"
    else
        log_error "❌ 发现 $errors 个问题，请检查系统状态"
    fi
}

# 重新加载配置
reload_config() {
    log_header "重新加载配置..."
    
    # 重新加载nginx配置
    log_step "重新加载nginx配置..."
    nginx -t && systemctl reload nginx
    log_info "✓ nginx配置重新加载完成"
    
    # 重启后端服务
    log_step "重启后端服务以加载新配置..."
    systemctl restart "$BACKEND_SERVICE"
    sleep 3
    
    if check_service_status "$BACKEND_SERVICE"; then
        log_info "✓ 后端服务重启成功"
    else
        log_error "✗ 后端服务重启失败"
        return 1
    fi
    
    log_info "配置重新加载完成"
}

# 备份当前部署
backup_deployment() {
    log_header "备份当前部署..."
    
    local backup_dir="/var/backups/$PROJECT_NAME/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份代码
    if [[ -d "$DEPLOY_BASE" ]]; then
        log_step "备份应用代码..."
        cp -r "$DEPLOY_BASE" "$backup_dir/"
        log_info "✓ 应用代码备份完成"
    fi
    
    # 备份配置文件
    log_step "备份配置文件..."
    mkdir -p "$backup_dir/configs"
    
    # nginx配置
    if [[ -f "/etc/nginx/sites-available/$PROJECT_NAME" ]]; then
        cp "/etc/nginx/sites-available/$PROJECT_NAME" "$backup_dir/configs/"
    fi
    
    # systemd服务配置
    if [[ -f "/etc/systemd/system/$BACKEND_SERVICE.service" ]]; then
        cp "/etc/systemd/system/$BACKEND_SERVICE.service" "$backup_dir/configs/"
    fi
    
    # 环境变量文件
    if [[ -f "$DEPLOY_BASE/backend/.env" ]]; then
        cp "$DEPLOY_BASE/backend/.env" "$backup_dir/configs/"
    fi
    
    # 备份数据库（如果有）
    if [[ -d "$DEPLOY_BASE/backend/data" ]]; then
        log_step "备份数据文件..."
        cp -r "$DEPLOY_BASE/backend/data" "$backup_dir/"
    fi
    
    # 设置备份权限
    chown -R www-data:www-data "$backup_dir"
    chmod -R 640 "$backup_dir"
    
    log_info "✓ 备份完成: $backup_dir"
    
    # 清理旧备份（保留最近10个）
    find "/var/backups/$PROJECT_NAME" -maxdepth 1 -type d -name "20*" | sort -r | tail -n +11 | xargs -r rm -rf
}

# 实时监控
monitor_services() {
    log_header "实时监控服务状态..."
    log_info "按Ctrl+C退出监控模式"
    echo ""
    
    while true; do
        clear
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 哄汤敏系统实时监控"
        echo "======================================================="
        
        # 服务状态
        show_status
        
        # 最近的日志
        echo "最近日志 (最后5条):"
        echo "-------------------"
        journalctl -u "$BACKEND_SERVICE" -n 5 --no-pager -o cat 2>/dev/null || echo "暂无日志"
        
        echo ""
        echo "下次更新: $(date -d '+10 seconds' '+%H:%M:%S')"
        
        sleep 10
    done
}

# 更新配置文件
update_config() {
    log_header "更新配置文件..."
    
    log_step "检查配置文件..."
    
    # 检查环境变量文件
    local env_file="$DEPLOY_BASE/backend/.env"
    if [[ -f "$env_file" ]]; then
        log_info "当前环境变量配置:"
        echo "----------------------------------------"
        grep -v "API_KEY" "$env_file" || true
        echo "IFLOW_API_KEY=****(已隐藏)"
        echo "----------------------------------------"
        
        read -p "是否需要编辑环境变量文件? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            vim "$env_file"
            log_info "环境变量文件已更新"
            
            read -p "是否立即重启服务以应用配置? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                restart_services
            fi
        fi
    else
        log_error "环境变量文件不存在: $env_file"
    fi
}

# 清理旧文件
cleanup_old_files() {
    log_header "清理旧日志和缓存..."
    
    # 清理日志文件
    log_step "清理旧日志..."
    if [[ -d "$LOG_DIR" ]]; then
        find "$LOG_DIR" -name "*.log*" -type f -mtime +30 -delete 2>/dev/null || true
        log_info "✓ 已清理30天前的日志文件"
    fi
    
    # 清理systemd日志
    log_step "清理systemd日志..."
    journalctl --vacuum-time=30d >/dev/null 2>&1 || true
    journalctl --vacuum-size=500M >/dev/null 2>&1 || true
    log_info "✓ 已清理systemd日志"
    
    # 清理临时文件
    log_step "清理临时文件..."
    find /tmp -name "*$PROJECT_NAME*" -type f -mtime +1 -delete 2>/dev/null || true
    
    # 清理npm缓存（如果存在）
    if command -v npm >/dev/null 2>&1; then
        npm cache clean --force >/dev/null 2>&1 || true
        log_info "✓ 已清理npm缓存"
    fi
    
    log_info "清理完成"
}

# 主函数
main() {
    local command=""
    local verbose=false
    local quiet=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                export VERBOSE=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                export QUIET=true
                shift
                ;;
            start|stop|restart|status|logs|health|reload|backup|monitor|update-config|cleanup)
                command="$1"
                shift
                break
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定命令，显示帮助
    if [[ -z "$command" ]]; then
        show_help
        exit 1
    fi
    
    # 检查root权限（除了某些只读命令）
    case $command in
        status|logs|health)
            # 这些命令不需要root权限
            ;;
        *)
            check_root
            ;;
    esac
    
    # 执行命令
    case $command in
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            show_status
            ;;
        logs)
            view_logs "$@"
            ;;
        health)
            health_check
            ;;
        reload)
            reload_config
            ;;
        backup)
            backup_deployment
            ;;
        monitor)
            monitor_services
            ;;
        update-config)
            update_config
            ;;
        cleanup)
            cleanup_old_files
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
