#!/usr/bin/env bash


mkdir -p /var/log/oray/
touch /var/log/oray/pgyvpn/pgyvistor.log


/one-exec.sh


(sleep 2 && tail -f /var/log/oray/pgyvpn/pgyvistor.log | awk '{print "/var/log/oray/pgyvpn/pgyvistor.log--文件输出: " $0}') &
(sleep 2 && tail -f /var/log/oray/pgyvpn_svr/pgyvpnsvr.log | awk '{print "/var/log/oray/pgyvpn_svr/pgyvpnsvr.log--文件输出: " $0}') &

# supervisord -c /etc/supervisord.conf
(sleep 1 && /usr/share/pgyvpn/script/pgystart) &


# 替换配置
/tinyproxy-run-proxy.sh

exec /docker-tinyproxy-run.sh "$@"


