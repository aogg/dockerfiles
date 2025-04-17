#!/usr/bin/env bash


mkdir -p /var/log/oray/pgyvpn/
touch /var/log/oray/pgyvpn/pgyvpn.log

tail -f /var/log/oray/pgyvpn/pgyvpn.log &


/one-exec.sh

# /usr/share/pgyvpn/script/pgystart &
/usr/share/pgyvpn/script/pgyvpn_monitor &


# 替换配置
/tinyproxy-run-proxy.sh


exec /docker-tinyproxy-run.sh "$@"


