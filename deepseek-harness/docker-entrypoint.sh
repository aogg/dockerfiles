#!/usr/bin/env bash
set -e

echo "=============================================="
echo " DeepSeek Harness 启动"
echo "=============================================="
dsh --version

PORT="${DSH_PORT:-3080}"
echo "监听端口 : ${PORT}"


# 判断：目录存在 且 目录内无任何文件
if [ -d "$DSH_HOME/profiles/web" ] && [ -z "$(ls -A "$DSH_HOME/profiles/web" 2>/dev/null)" ];then
  mv "$DSH_HOME/profiles/web_bak" "$DSH_HOME/profiles/web"
  cp $DSH_HOME/profiles/web/cordis.patch.yml $DSH_HOME/profiles/web/cordis.yml
fi

echo dsh --profile web --dump-config
dsh --profile web --dump-config

# 监听地址为 0.0.0.0（由 profile 的 cordis.patch.yml 配置层覆盖，
# dsh CLI 故意拒绝 --host 0.0.0.0，只能走配置层）
# 容器需向外部暴露端口：docker run -p 3080:3080 ...
#
# 额外参数原样透传，例如浏览器从局域网 IP/域名访问时：
#   docker run ... -e DSH_TRUSTED_HOST="192.168.1.5" ...
if [ -n "$DSH_TRUSTED_HOST" ]; then
  # 支持逗号分隔多个 host:port
  TRUSTED_ARGS=()
  IFS=',' read -ra HOSTS <<< "$DSH_TRUSTED_HOST"
  for h in "${HOSTS[@]}"; do
    TRUSTED_ARGS+=(--trusted-host "$h")
  done
  set -- "${TRUSTED_ARGS[@]}" "$@"
fi

echo 
echo cat $DSH_HOME/profiles/web_bak/cordis.patch.yml
cat $DSH_HOME/profiles/web_bak/cordis.patch.yml

exec dsh --profile web --port "${PORT}" "$@"