# 配置端口插件

在 Mainsail/Fluidd 中根据访问端口控制配置功能的显示：
- **端口 80**：普通访问，隐藏配置（Machine/Configure/System/Settings）
- **端口 5337**：管理访问，显示完整配置

## 功能

- **端口 80**：侧边栏隐藏配置入口，直接访问 `/config`、`/configure` 等会被重定向到首页
- **端口 5337**：显示所有配置功能

## 一键安装

在 Klipper 主机终端执行：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/zhangbo010/config-port-plugin/main/install.sh)
```

或先下载再执行：

```bash
wget -q -O install.sh https://raw.githubusercontent.com/zhangbo010/config-port-plugin/main/install.sh
bash install.sh
```

## 使用

- 普通用户：`http://<设备IP>/` 或 `http://<设备IP>:80/`
- 管理员：`http://<设备IP>:5337/`

## 手动安装

1. 将 `config-port-plugin.js` 复制到 Mainsail/Fluidd 的 web 根目录
2. 在 nginx 的 `location /` 块中添加 `sub_filter` 注入脚本
3. 添加 5337 端口的 server 块，参考 `nginx-config-port-plugin.conf`

## 自定义

编辑 `config-port-plugin.js` 可修改：
- `CONFIG_PORT`：显示配置的端口号（默认 5337）
- `RESTRICTED_PATHS`：需要隐藏的路径列表

## 许可证

GNU GPLv3
