#!/usr/bin/env bash
set -e

echo "=============================================="
echo " DeepSeek Harness 启动"
echo "=============================================="
dsh --version

PORT="${DSH_PORT:-3080}"
echo "监听端口 : ${PORT}"


# 判断：目录存在 且 目录内无任何文件
cpBool=0
if [ ! -d "$DSH_HOME/" ] || [ -z "$(ls -A "$DSH_HOME/" 2>/dev/null)" ];then
  echo "不存在web文件夹，开始cp";

  cp -a "${DSH_HOME}_bak/." "$DSH_HOME/"
  ls -al $DSH_HOME/profiles/web

  cp $DSH_HOME/profiles/web/cordis.patch.yml $DSH_HOME/profiles/web/cordis.yml.bak
  cpBool=1

  
echo dsh --profile web --dump-config
dsh --profile web --dump-config

fi

if [ "$cpBool" -eq 1 ];then
  echo "不存在web文件夹，开始cp, yml";

  cp -f $DSH_HOME/profiles/web/cordis.yml.bak $DSH_HOME/profiles/web/cordis.yml
  cat $DSH_HOME/profiles/web/cordis.yml
else
  echo "已存在web文件夹"  
fi

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

# 执行初始化脚本目录：$DSH_HOME/docker-entrypoint-init-sh/*.sh
# 目录不存在时跳过；脚本按文件名顺序执行；任一脚本失败即终止启动（受 set -e 影响）
if [ -d "$DSH_HOME/docker-entrypoint-init-sh" ]; then
  shopt -s nullglob
  for f in "$DSH_HOME"/docker-entrypoint-init-sh/*.sh; do
    echo "执行初始化脚本: $f"
    bash "$f"
  done
else
  echo "未发现初始化脚本目录: $DSH_HOME/docker-entrypoint-init-sh，跳过"
fi


echo 
echo cat $DSH_HOME/profiles/web/cordis.patch.yml
cat $DSH_HOME/profiles/web/cordis.patch.yml


echo "启动"
exec dsh --profile web --port "${PORT}" --no-open "$@"