#!/bin/ash


mkcert -install;
ls -al /root/.local/share/mkcert/;
# rm -f /etc/nginx/ssl/mkcert/rootCA.pem;
# rm -f /etc/nginx/ssl/mkcert/rootCA-key.pem;
mkdir -p /mkcert-pem/;
cp -a /root/.local/share/mkcert/* /mkcert-pem/;
chmod 666 /mkcert-pem/*;


exec /docker-run.sh