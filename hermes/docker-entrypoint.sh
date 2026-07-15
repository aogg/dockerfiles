#!/usr/bin/env ash 


if [ ! -d "/opt/data" ]; then
    mv /opt/data.bak /opt/data
fi

# hermes-web-ui start &

echo "HERMES_ORIG_CWD="
echo $HERMES_ORIG_CWD
env

(sleep 4 && cd $HERMES_ORIG_CWD && runuser -m -u hermes -- hermes dashboard --host 0.0.0.0 --port 9119 --no-open --insecure) &

exec runuser -m -u hermes -- hermes "$@"