#!/usr/bin/env bash


mkdir -p /var/log/oray/pgyvpn/
touch /var/log/oray/pgyvpn/pgyvpn.log

tail -f /var/log/oray/pgyvpn/pgyvpn.log &

# /usr/share/pgyvpn/script/pgystart &
/usr/share/pgyvpn/script/pgyvpn_monitor &

exec /docker-tinyproxy-run.sh "$@"


