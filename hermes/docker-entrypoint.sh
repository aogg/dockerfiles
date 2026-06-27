#!/usr/bin/env ash 


if [ -d "/opt/data" ]; then
    mv /opt/data.bak /opt/data
fi

# hermes-web-ui start &

exec /opt/hermes/docker/main-wrapper.sh "$@"