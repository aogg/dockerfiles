#!/usr/bin/env bash 



# 每分钟清理log
while true; do
    tail -n 1000 /var/log/tinyproxy/tinyproxy.log > /var/log/tinyproxy/tinyproxy.log.tmp
    cat /var/log/tinyproxy/tinyproxy.log.tmp > /var/log/tinyproxy/tinyproxy.log
    sleep 60
done

exec /opt/docker-tinyproxy/run.sh $@