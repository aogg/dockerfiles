#!/usr/bin/env ash 


if [ ! -d "/opt/data" ]; then
    mv /opt/data.bak /opt/data
fi

# hermes-web-ui start &


(sleep 4 && cd $HERMES_ORIG_CWD && su -m hermes -c 'hermes dashboard --host 0.0.0.0 --port 9119 --no-open --insecure') &

exec /opt/hermes/docker/main-wrapper.sh "$@"