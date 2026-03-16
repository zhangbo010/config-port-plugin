#!/bin/bash
# Mainsail/Fluidd 配置端口插件 - 一键安装脚本
# 在 Klipper 主机（树莓派等）上执行: bash install.sh

set -e

# 发布到 GitHub 后，将 config-port-plugin 改为你的仓库名
REPO_URL="https://raw.githubusercontent.com/zhangbo010/config-port-plugin/main"
CONFIG_PORT="5337"

echo "=========================================="
echo " 配置端口插件 - 一键安装"
echo "=========================================="
echo ""

# 检测 Mainsail/Fluidd 路径
WEB_ROOT=""
for path in "/home/pi/mainsail" "/home/mainsail/mainsail" "/home/pi/fluidd" "/home/fluidd/fluidd" \
            "/root/mainsail" "/root/fluidd" "$HOME/mainsail" "$HOME/fluidd" \
            "/usr/share/mainsail" "/usr/share/fluidd" \
            "/var/www/mainsail" "/var/www/fluidd" "/opt/mainsail" "/opt/fluidd"; do
    if [ -d "$path" ] && [ -f "$path/index.html" ]; then
        WEB_ROOT="$path"
        break
    fi
done

# 从 nginx 配置中提取 root 路径
if [ -z "$WEB_ROOT" ]; then
    for cfg in /etc/nginx/sites-available/mainsail /etc/nginx/sites-available/fluidd \
               /etc/nginx/sites-enabled/mainsail /etc/nginx/sites-enabled/fluidd; do
        if [ -f "$cfg" ]; then
            # 提取 root 指令后的路径（去除分号）
            found=$(grep -E "^\s*root\s+" "$cfg" 2>/dev/null | head -1 | sed -E 's/.*root[[:space:]]+([^;]+);/\1/' | tr -d ' ')
            if [ -n "$found" ] && [ -d "$found" ] && [ -f "$found/index.html" ]; then
                WEB_ROOT="$found"
                break
            fi
        fi
    done
fi

if [ -z "$WEB_ROOT" ]; then
    echo "错误: 未找到 Mainsail 或 Fluidd 安装目录"
    echo ""
    echo "查找路径: find / -name index.html -path '*mainsail*' 2>/dev/null"
    echo "或查看 nginx 配置: grep -r 'root' /etc/nginx/"
    echo ""
    echo "找到后执行: WEB_ROOT=/实际路径 bash install.sh"
    exit 1
fi

echo "检测到 Web 根目录: $WEB_ROOT"
echo ""

# 1. 下载插件
echo "[1/3] 安装 config-port-plugin.js ..."
if command -v wget &>/dev/null; then
    wget -q -O "$WEB_ROOT/config-port-plugin.js" "$REPO_URL/config-port-plugin.js"
elif command -v curl &>/dev/null; then
    curl -sSL -o "$WEB_ROOT/config-port-plugin.js" "$REPO_URL/config-port-plugin.js"
else
    echo "错误: 需要 wget 或 curl"
    exit 1
fi

echo " 已安装到: $WEB_ROOT/config-port-plugin.js"
echo ""

# 2. 配置 Nginx
echo "[2/3] 配置 Nginx ..."
NGINX_CFG=""
for cfg in "/etc/nginx/sites-available/mainsail" "/etc/nginx/sites-available/fluidd" \
           "/etc/nginx/sites-enabled/mainsail" "/etc/nginx/sites-enabled/fluidd" \
           "/etc/nginx/conf.d/mainsail.conf" "/etc/nginx/conf.d/fluidd.conf"; do
    if [ -f "$cfg" ]; then
        NGINX_CFG="$cfg"
        break
    fi
done

if [ -z "$NGINX_CFG" ]; then
    echo " 未找到 Nginx 配置文件，请手动配置"
    echo ""
    echo " 在 location / 块中添加:"
    echo "   sub_filter '</body>' '<script src=\"/config-port-plugin.js\"></script></body>';"
    echo "   sub_filter_once on;"
    echo "   sub_filter_types text/html;"
    echo ""
    echo " 并添加 5337 端口的 server 块，参考 nginx-config-port-plugin.conf"
    echo ""
else
    # 备份
    if [ ! -f "${NGINX_CFG}.config-port-plugin.bak" ]; then
        sudo cp "$NGINX_CFG" "${NGINX_CFG}.config-port-plugin.bak"
        echo " 已备份: ${NGINX_CFG}.config-port-plugin.bak"
    fi

    # 检查 sub_filter 是否已配置
    if grep -q "config-port-plugin" "$NGINX_CFG" 2>/dev/null; then
        echo " Nginx 已包含插件脚本注入，跳过"
    else
        # 使用 Python 注入 sub_filter（兼容性更好）
        TMP_CFG="/tmp/nginx_config_port_plugin_$$"
        sudo cat "$NGINX_CFG" > "$TMP_CFG"
        python3 << PYEOF
import re

with open("$TMP_CFG", "r") as f:
    content = f.read()

if "config-port-plugin" in content:
    print("Already patched")
    exit(0)

# 简单替换：在 try_files 行前添加 sub_filter
old = "try_files \$uri \$uri/ /index.html;"
new = """sub_filter '</body>' '<script src="/config-port-plugin.js"></script></body>';
        sub_filter_once on;
        sub_filter_types text/html;
        try_files \$uri \$uri/ /index.html;"""
if old in content:
    new_content = content.replace(old, new)
    with open("$TMP_CFG", "w") as f:
        f.write(new_content)
    print("Patched location /")
else:
    print("Could not auto-patch, please add sub_filter manually")
    exit(1)
PYEOF
        sudo cp "$TMP_CFG" "$NGINX_CFG"
        rm -f "$TMP_CFG"
    fi

    # 在端口 80 的 location /server 中拦截 config API（阻止访问 printer.cfg 等）
    if ! grep -q "root=config" "$NGINX_CFG" 2>/dev/null; then
        TMP_PID=$$
        sudo cat "$NGINX_CFG" > "/tmp/nginx_cpp_$TMP_PID"
        python3 << PYPATCH
path = "/tmp/nginx_cpp_$TMP_PID"
with open(path, "r") as f:
    content = f.read()
old = "location /server {"
block = """location /server {
    if (\$request_uri ~ "root=config") { return 403; }
    if (\$request_uri ~ "path=config") { return 403; }
    if (\$request_uri ~ "filename=config") { return 403; }
    if (\$request_uri ~ "^/server/files/config") { return 403; }
"""
if old in content:
    content = content.replace(old, block, 1)
    with open(path, "w") as f:
        f.write(content)
    print(" 已拦截端口 80 的 config API")
PYPATCH
        sudo cp "/tmp/nginx_cpp_$TMP_PID" "$NGINX_CFG"
        rm -f "/tmp/nginx_cpp_$TMP_PID"
    fi

    # 添加 5337 端口 server 块
    if ! grep -q "listen $CONFIG_PORT" "$NGINX_CFG" 2>/dev/null; then
            # 创建 5337 server 块并追加
            sudo tee -a "$NGINX_CFG" > /dev/null << NGINXEOF

# 配置端口插件 - 5337 管理端口
server {
    listen $CONFIG_PORT;
    listen [::]:$CONFIG_PORT;
    root $WEB_ROOT;
    index index.html;
    server_name _;
    client_max_body_size 200M;
    location / {
        sub_filter '</body>' '<script src="/config-port-plugin.js"></script></body>';
        sub_filter_once on;
        sub_filter_types text/html;
        try_files \$uri \$uri/ /index.html;
    }
    location /printer { proxy_pass http://127.0.0.1:7125/printer; proxy_set_header Host \$http_host; proxy_set_header X-Real-IP \$remote_addr; }
    location /api { proxy_pass http://127.0.0.1:7125/api; proxy_set_header Host \$http_host; proxy_set_header X-Real-IP \$remote_addr; }
    location /access { proxy_pass http://127.0.0.1:7125/access; proxy_set_header Host \$http_host; proxy_set_header X-Real-IP \$remote_addr; }
    location /websocket { proxy_pass http://127.0.0.1:7125/websocket; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$http_host; proxy_read_timeout 86400; }
    location /machine { proxy_pass http://127.0.0.1:7125/machine; proxy_set_header Host \$http_host; proxy_set_header X-Real-IP \$remote_addr; }
    location /server { proxy_pass http://127.0.0.1:7125/server; proxy_set_header Host \$http_host; proxy_set_header X-Real-IP \$remote_addr; }
}
NGINXEOF
        echo " 已添加 $CONFIG_PORT 端口 server 块"
    fi
fi
echo ""

# 3. 重载 Nginx
echo "[3/3] 重载 Nginx ..."
if sudo nginx -t 2>/dev/null; then
    sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null || true
    echo " Nginx 已重载"
else
    echo " 警告: nginx -t 失败，请检查配置"
    echo " 可恢复备份: sudo cp ${NGINX_CFG}.config-port-plugin.bak $NGINX_CFG"
fi

echo ""
echo "=========================================="
echo " 安装完成!"
echo "=========================================="
echo ""
echo "端口 80:  http://<设备IP>/         (隐藏配置)"
echo "端口 $CONFIG_PORT: http://<设备IP>:$CONFIG_PORT/  (显示配置)"
echo ""
