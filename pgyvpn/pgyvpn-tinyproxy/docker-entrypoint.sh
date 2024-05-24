#!/usr/bin/env bash


mkdir -p /var/log/oray/
touch /var/log/oray/pgyvpn/pgyvistor.log

(sleep 2 && tail -f /var/log/oray/pgyvpn/pgyvistor.log) &

/one-exec.sh

supervisord -c /etc/supervisord.conf
# (sleep 1 && /usr/share/pgyvpn/script/pgystart) &

exec /docker-tinyproxy-run.sh "$@"


