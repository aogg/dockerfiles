#!/usr/bin/env bash 



# 每分钟清理log
{
    while true; do
        tail -n 1000 /var/log/tinyproxy/tinyproxy.log > /var/log/tinyproxy/tinyproxy.log.tmp
        cat /var/log/tinyproxy/tinyproxy.log.tmp > /var/log/tinyproxy/tinyproxy.log
        sleep 60
    done
} &

# 如果存在环境变量 DELETE_ALL_CONNECT_PORTS，则删除 ConnectPort 配置
if [ -n "$DELETE_ALL_CONNECT_PORTS" ]; then
    echo "删除所有 ConnectPort 配置"
    sed -i "/ConnectPort/d" /etc/tinyproxy/tinyproxy.conf
fi

exec /opt/docker-tinyproxy/run.sh $@