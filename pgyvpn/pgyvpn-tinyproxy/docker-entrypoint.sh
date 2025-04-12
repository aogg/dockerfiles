#!/usr/bin/env bash


mkdir -p /var/log/oray/
touch /var/log/oray/pgyvpn/pgyvistor.log


/one-exec.sh


(sleep 2 && tail -f /var/log/oray/pgyvpn/pgyvistor.log | awk '{print "/var/log/oray/pgyvpn/pgyvistor.log--文件输出: " $0}') &
(sleep 2 && tail -f /var/log/oray/pgyvpn_svr/pgyvpnsvr.log | awk '{print "/var/log/oray/pgyvpn_svr/pgyvpnsvr.log--文件输出: " $0}') &

# supervisord -c /etc/supervisord.conf
(sleep 1 && /usr/share/pgyvpn/script/pgystart) &


# 替换配置
if [ -n "$TINYPROXY_PROXY" ];then
    sed -i -e "s%upstream http.*%upstream http `echo $TINYPROXY_PROXY`%g" /etc/tinyproxy/tinyproxy-proxy.conf
fi
(/usr/sbin/tinyproxy -c /etc/tinyproxy/tinyproxy-proxy.conf)

exec /docker-tinyproxy-run.sh "$@"


