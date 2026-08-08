#!/usr/bin/env ash 


if [ ! -d "/opt/data" ]; then
    mv /opt/data.bak /opt/data
    chown -R hermes:hermes /opt/data
fi

# 设置时区 start
# 通过 TZ 环境变量设置容器时区（entrypoint 以 root 运行，hermes 用户无权限改 /etc/localtime）
if [ -n "$TZ" ]; then
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
fi
# 设置时区 end

# hermes-web-ui start &

echo "HERMES_ORIG_CWD="
echo $HERMES_ORIG_CWD
env

# (sleep 4 && cd $HERMES_ORIG_CWD && runuser -m -u hermes -- hermes dashboard --host 0.0.0.0 --port 9119 --no-open --insecure) &

(sleep 4 && cd $HERMES_ORIG_CWD && hermes dashboard --host 0.0.0.0 --port 9119 --no-open --insecure) &

(sleep 6 && hermes dashboard --status) &

exec runuser -m -u hermes -- hermes "$@"