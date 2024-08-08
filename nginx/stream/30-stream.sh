#!/bin/sh

CONFIG_FILE=${CONFIG_FILE:-/etc/nginx/nginx.conf}


if cat /etc/nginx/nginx.conf|grep "stream {"; then
    echo '已配置过';
    exit;
fi

{
    echo "stream {"
    echo "    log_format tcp_log '\$remote_addr:\$remote_port  \$upstream_addr  - \$status - \$bytes_sent - \$bytes_received tcp_log';"
    echo "    log_format udp_log '\$remote_addr:\$remote_port  \$upstream_addr  - \$status - \$bytes_sent - \$bytes_received udp_log';"
    echo "    error_log /var/log/nginx/error.log;"
    echo ""
    echo "    # 代理 TCP 流量"
    echo "    upstream tcp_upstream {"
    echo "        $TCP_UPSTREAM_CONTENT"  # 使用 TCP 上游内容
    echo "    }"
    echo ""
    echo "    server {"
    echo "        listen $TCP_PORT;"  # 使用 TCP 端口
    echo "        proxy_pass tcp_upstream;"
    echo "        access_log /var/log/nginx/access.log tcp_log;"
    echo "    }"
    echo ""

    # 只有在 UDP_PORT 存在时才包含 UDP 配置
    if [ -n "$UDP_PORT" ]; then
        echo "    # 代理 UDP 流量"
        echo "    upstream udp_upstream {"
        echo "        $UDP_UPSTREAM_CONTENT"  # 使用 UDP 上游内容
        echo "    }"
        echo ""
        echo "    server {"
        echo "        listen $UDP_PORT udp;"  # 使用 UDP 端口
        echo "        proxy_pass udp_upstream;"
        echo "        access_log /var/log/nginx/access.log udp_log;"
        echo "    }"
        echo ""
    fi

    echo "}"
} >> "$CONFIG_FILE"

# sed -i \
#     -e "s/{TCP_UPSTREAM_CONTENT}/$TCP_UPSTREAM_CONTENT/" \
#     -e "s/{TCP_PORT}/$TCP_PORT/" \
#     -e "s/{UDP_UPSTREAM_CONTENT}/$UDP_UPSTREAM_CONTENT/" \
#     -e "s/{UDP_PORT}/$UDP_PORT/" \
#     /etc/nginx/conf.d/stream.conf

echo '配置成功';

