#!/usr/bin/env bash
set -u

# 环境变量说明:
#   HOST_URL_<NAME>=<url>   需要下载的 hosts 文件, 下载到 /data/hosts.d/<name>
#                           例: HOST_URL_ADBLOCK=https://xxx/hosts  ->  /data/hosts.d/adblock
#   HOST_FETCH_INTERVAL     循环下载间隔(秒), 默认 3600
#
# 最终把 初始 hosts + /data/hosts.d/ 下所有文件 合并成 /data/hosts
# (coredns hosts 插件只能读单个文件, Corefile 里 hosts /data/hosts 指向合并文件)

HOSTS_FILE="/data/hosts"        # coredns 读取的合并文件
HOSTS_DIR="/data/hosts.d"       # HOST_URL_* 的下载目录
BASE_FILE="/data/hosts.base"    # 镜像内置初始 hosts 的备份, 作为合并基底
INTERVAL="${HOST_FETCH_INTERVAL:-3600}"

echo "=============================================="
echo " CoreDNS hosts 下载器"
echo " 下载目录 : ${HOSTS_DIR}"
echo " 合并文件 : ${HOSTS_FILE}"
echo " 循环间隔 : ${INTERVAL}s"
echo "=============================================="

# 收集所有 HOST_URL_* 变量名
URL_VARS=()
for var in "${!HOST_URL_@}"; do
  URL_VARS+=("$var")
done

if [ "${#URL_VARS[@]}" -eq 0 ]; then
  echo "未发现 HOST_URL_* 环境变量，跳过下载，直接启动"
  exec /coredns "$@"
fi

echo "发现 ${#URL_VARS[@]} 个 HOST_URL_* 变量:"
for var in "${URL_VARS[@]}"; do
  echo "  ${var}=${!var}"
done

# 首次启动时备份初始 hosts, 之后合并都基于它 (卷持久化后仍是原内容)
if [ ! -f "$BASE_FILE" ] && [ -f "$HOSTS_FILE" ]; then
  cp -f "$HOSTS_FILE" "$BASE_FILE"
fi

mkdir -p "$HOSTS_DIR"

# 下载单个文件, 失败只报错不中断, 保留旧文件
fetch_one() {
  local name="$1" url="$2"
  local dest="${HOSTS_DIR}/${name}"
  local tmp="${dest}.tmp"

  echo "[fetch] ${url} -> ${dest}"
  if curl -fsSL --connect-timeout 10 --max-time 120 -o "$tmp" "$url"; then
    mv -f "$tmp" "$dest"
    echo "[ok]    ${name} 共 $(wc -l < "$dest") 行"
  else
    rm -f "$tmp"
    echo "[err]   下载失败，跳过: ${url}" >&2
  fi
}

fetch_all() {
  for var in "${URL_VARS[@]}"; do
    # HOST_URL_ADBLOCK -> adblock
    local name="${var#HOST_URL_}"
    name="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
    local url="${!var}"
    [ -z "$url" ] && continue
    fetch_one "$name" "$url"
  done

  # 合并: 初始 hosts + 下载的所有文件 -> /data/hosts
  # 先写临时文件再 mv, 避免 coredns reload 读到半截文件
  local merged="${HOSTS_FILE}.new"
  {
    [ -f "$BASE_FILE" ] && cat "$BASE_FILE"
    shopt -s nullglob
    for f in "$HOSTS_DIR"/*; do
      echo ""
      echo "# >>> ${f}"
      cat "$f"
    done
  } > "$merged"

  if [ -s "$merged" ]; then
    mv -f "$merged" "$HOSTS_FILE"
    echo "[merge] 已更新 ${HOSTS_FILE}"
  else
    rm -f "$merged"
    echo "[merge] 合并结果为空，保留原文件"
  fi
}

fetch_loop() {
  while true; do
    echo "----------------------------------------------"
    fetch_all
    sleep "$INTERVAL"
  done
}

fetch_loop &
echo "下载循环已启动 (pid=$!)"

# Corefile 配置了 reload 5s, hosts 文件更新后 coredns 自动生效
echo "启动 coredns"
exec /coredns "$@"
