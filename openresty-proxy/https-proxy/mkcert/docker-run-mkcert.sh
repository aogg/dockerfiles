#!/bin/ash


mkcert -install;
ls -al /root/.local/share/mkcert/;

exec /docker-run.sh