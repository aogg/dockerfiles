#!/usr/bin/env bash
set -e

echo "=============================================="
echo " SNIProxy 启动"
echo "=============================================="
sniproxy -v || true

# 基础配置文件路径（可通过 -e SNIPROXY_CONFIG=xxx 覆盖）
CONFIG_FILE="${SNIPROXY_CONFIG:-/etc/sniproxy/config.yaml}"

# socks5 前置代理地址：优先使用 -e SOCKS5_ADDR=ip:port
# 也支持分开指定 -e SOCKS5_HOST=ip -e SOCKS5_PORT=port
if [ -z "$SOCKS5_ADDR" ] && [ -n "$SOCKS5_HOST" ] && [ -n "$SOCKS5_PORT" ]; then
    SOCKS5_ADDR="${SOCKS5_HOST}:${SOCKS5_PORT}"
fi

if [ -n "$SOCKS5_ADDR" ]; then
    # 简单校验格式：必须为 ip:port 形式（必须包含冒号）
    case "$SOCKS5_ADDR" in
        *:*) ;;
        *)
            echo "错误：SOCKS5_ADDR 格式应为 ip:port（当前值：${SOCKS5_ADDR}）"
            exit 1
            ;;
    esac

    # 生成运行时配置副本（不改动挂载进来的原配置文件）
    RUNTIME_CONFIG="/tmp/sniproxy-runtime.yaml"
    cp -f "$CONFIG_FILE" "$RUNTIME_CONFIG"

    # 删除已有的 socks5 相关配置行（自定义配置里可能已启用，先移除避免 YAML 重复键冲突）
    sed -i -E '/^[[:space:]]*(enable_socks5|socks_addr|socks_username|socks_password):/d' "$RUNTIME_CONFIG"

    # 追加 socks5 前置代理配置
    {
        echo ""
        echo "# 以下由环境变量自动生成（SOCKS5_ADDR=${SOCKS5_ADDR}）"
        echo "enable_socks5: true"
        echo "socks_addr: ${SOCKS5_ADDR}"
        # 可选：代理账号密码（-e SOCKS5_USERNAME=xxx -e SOCKS5_PASSWORD=xxx）
        if [ -n "$SOCKS5_USERNAME" ]; then
            echo "socks_username: ${SOCKS5_USERNAME}"
        fi
        if [ -n "$SOCKS5_PASSWORD" ]; then
            echo "socks_password: ${SOCKS5_PASSWORD}"
        fi
    } >> "$RUNTIME_CONFIG"

    echo "已启用 Socks5 前置代理: ${SOCKS5_ADDR}"
    if [ -n "$SOCKS5_USERNAME" ]; then
        echo "已配置 Socks5 代理账号: ${SOCKS5_USERNAME}"
    fi
    CONFIG_FILE="$RUNTIME_CONFIG"
else
    echo "未设置 SOCKS5_ADDR，不启用 socks5 前置代理"
fi

echo "使用配置文件: ${CONFIG_FILE}"

# 过滤掉传入参数中的 -c 及其值（统一使用上面处理后的配置文件启动）
ARGS=()
skip=0
for arg in "$@"; do
    if [ "$skip" -eq 1 ]; then
        # 跳过 -c 后面紧跟的配置文件路径
        skip=0
        continue
    fi
    if [ "$arg" = "-c" ]; then
        skip=1
        continue
    fi
    case "$arg" in
        -c=*) continue ;; # 兼容 -c=/path 写法
    esac
    ARGS+=("$arg")
done

# 启动（额外参数如 -d 调试模式原样透传）
exec sniproxy -c "$CONFIG_FILE" "${ARGS[@]}"
