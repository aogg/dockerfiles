#!/usr/bin/env bash


mkdir -p /var/log/oray/pgyvpn/
touch /var/log/oray/pgyvpn/pgyvpn.log

tail -f /var/log/oray/pgyvpn/pgyvpn.log &


/one-exec.sh

# /usr/share/pgyvpn/script/pgystart &
/usr/share/pgyvpn/script/pgyvpn_monitor &


# 替换配置
if [ -n "$TINYPROXY_PROXY" ];then
    sed -i -e "s%upstream http.*%upstream http `echo $TINYPROXY_PROXY`%g" /etc/tinyproxy/tinyproxy-proxy.conf
fi
(/usr/sbin/tinyproxy -c /etc/tinyproxy/tinyproxy-proxy.conf)


exec /docker-tinyproxy-run.sh "$@"


