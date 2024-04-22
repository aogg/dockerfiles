#!/usr/bin/env bash


mkdir -p /var/log/oray/
touch /var/log/oray/pgyvpn/pgyvistor.log

(sleep 2 && tail -f /var/log/oray/pgyvpn/pgyvistor.log) &

/one-exec.sh

(sleep 1 && /usr/share/pgyvpn/script/pgystart) &

exec socat -v TCP-LISTEN:8888,fork,reuseaddr TCP:$PROXY_IP:$PROXY_PORT "$@"


