#!/usr/bin/env bash
set -u

# 环境变量说明:
#   HOST_URL_<NAME>=<url>   需要下载的 hosts 文件, 下载到 /data/hosts.d/<name>
#                           例: HOST_URL_ADBLOCK=https://xxx/hosts  ->  /data/hosts.d/adblock
#   HOST_FETCH_INTERVAL     循环下载间隔(秒), 默认 3600
#   HOST_FALLBACK_FORWARD   未匹配 hosts 时是否回退到 forward 上游, 默认 true
#                           设为 false/0/no/off 时移除 forward, 未匹配直接返回 SERVFAIL
#
# 最终把 初始 hosts + /data/hosts.d/ 下所有文件 合并成 /data/hosts
# (coredns hosts 插件只能读单个文件, Corefile 里 hosts /data/hosts 指向合并文件)

HOSTS_FILE="/data/hosts"        # coredns 读取的合并文件
HOSTS_DIR="/data/hosts.d"       # HOST_URL_* 的下载目录
BASE_FILE="/data/hosts.base"    # 镜像内置初始 hosts 的备份, 作为合并基底
INTERVAL="${HOST_FETCH_INTERVAL:-3600}"
FALLBACK_FORWARD="${HOST_FALLBACK_FORWARD:-true}"

# 判断布尔 env 是否为"假" (false/0/no/off, 大小写不敏感)
is_false() {
  case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    false|0|no|off) return 0 ;;
    *) return 1 ;;
  esac
}

echo "=============================================="
echo " CoreDNS hosts 下载器"
echo " 下载目录 : ${HOSTS_DIR}"
echo " 合并文件 : ${HOSTS_FILE}"
echo " 循环间隔 : ${INTERVAL}s"
if is_false "$FALLBACK_FORWARD"; then
  echo " 回退转发 : 关闭 (hosts 未命中的查询直接返回 SERVFAIL)"
else
  echo " 回退转发 : 开启 (hosts 未命中转发上游)"
fi
echo "=============================================="

# 根据 HOST_FALLBACK_FORWARD 生成实际使用的 Corefile 并启动:
# 关闭回退时移除 forward 行, hosts 插件 fallthrough 后无插件处理, coredns 返回 SERVFAIL
start_coredns() {
  local src="/etc/coredns/Corefile"
  local conf="$src"

  if is_false "$FALLBACK_FORWARD" && grep -qE '^[[:space:]]*forward[[:space:]]' "$src"; then
    conf="/tmp/Corefile.no-forward"
    sed -E '/^[[:space:]]*forward[[:space:]]/d' "$src" > "$conf"
    echo "[conf] HOST_FALLBACK_FORWARD=${FALLBACK_FORWARD}: 已移除 forward, hosts 未命中的查询将直接返回 SERVFAIL"
  fi

  # 把 -conf 指向生成的文件, 未传 -conf 时补上
  local args=() replaced=0
  while [ $# -gt 0 ]; do
    if [ "$1" = "-conf" ] && [ $# -ge 2 ]; then
      args+=("$1" "$conf")
      replaced=1
      shift 2
    else
      args+=("$1")
      shift
    fi
  done
  [ "$replaced" -eq 0 ] && args=(-conf "$conf" "${args[@]}")

  exec /coredns "${args[@]}"
}

# 收集所有 HOST_URL_* 变量名
URL_VARS=()
for var in "${!HOST_URL_@}"; do
  URL_VARS+=("$var")
done

if [ "${#URL_VARS[@]}" -eq 0 ]; then
  echo "未发现 HOST_URL_* 环境变量，跳过下载，直接启动"
  start_coredns "$@"
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
start_coredns "$@"
