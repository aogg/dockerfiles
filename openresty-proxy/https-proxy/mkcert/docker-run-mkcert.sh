#!/bin/ash


mkcert -install;
ls -al /root/.local/share/mkcert/;
rm -f /etc/nginx/ssl/mkcert/rootCA.pem;
rm -f /etc/nginx/ssl/mkcert/rootCA-key.pem;
cp -a /root/.local/share/mkcert/ /etc/nginx/ssl/;

exec /docker-run.sh