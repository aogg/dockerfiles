#!/usr/bin/env bash 


/one-exec.sh

/docker-tinyproxy-run.sh ANY &
tail -f /var/log/tinyproxy/tinyproxy.log &;



exec /docker-entrypoint.sh

