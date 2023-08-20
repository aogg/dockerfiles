#!/usr/bin/env bash


mkdir -p /var/log/oray/
touch /var/log/oray/pgyvpn/pgyvistor.log

tail -f /var/log/oray/pgyvpn/pgyvistor.log &

/usr/share/pgyvpn/script/pgystart &

exec /docker-tinyproxy-run.sh "$@"


