#!/bin/ash

# mkcert -install;
# cd /root/.local/share/mkcert/;

hostName=$1
mkcert -key-file  "/etc/nginx/ssl/${hostName}.key" -cert-file  "/etc/nginx/ssl/${hostName}.crt" "${hostName}";
#  cat rootCA.pem  ${hostName}.crt >> certificate.crt