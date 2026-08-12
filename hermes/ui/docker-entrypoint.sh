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

echo "HERMES_ORIG_CWD="
echo $HERMES_ORIG_CWD
env

# hermes dashboard 后台启动（继承自基础镜像 entrypoint 的逻辑）
(sleep 4 && cd $HERMES_ORIG_CWD && hermes dashboard --host 0.0.0.0 --port 9119 --no-open --insecure) &

(sleep 6 && hermes dashboard --status) &

# hermes-hudui 后台启动
# hudui 读取 hermes 数据目录，需通过 HERMES_HOME 指向 /opt/data
# 容器内需绑定 0.0.0.0 以便外部访问，使用 --unsafe-allow-remote（仅在可信网络中使用）
# NFS/WSL1/绑定挂载环境下可设置 HERMES_HUD_FORCE_POLLING=1 以启用轮询替代文件事件
export HERMES_HOME="${HERMES_HOME:-/opt/data}"
(sleep 8 && cd /opt/hermes-hudui && runuser -m -u hermes -- /opt/hermes-hudui/venv/bin/hermes-hudui --host 0.0.0.0 --port 3001 --unsafe-allow-remote) &

exec runuser -m -u hermes -- hermes "$@"
