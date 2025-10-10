#!/bin/ash


mkcert -install;
ls -al /root/.local/share/mkcert/;
cp -a /root/.local/share/mkcert/ /etc/nginx/ssl/;

exec /docker-run.sh