#!/usr/bin/env bash
# =============================================================================
# my-plugin-init.sh —— dsh-lanmode 局域网 IP 自动注入
#
# 由 docker-entrypoint.sh 启动时执行：$DSH_HOME/docker-entrypoint-init-sh/*.sh
# 作用：把当前局域网 IP 所在的 /24 网段追加进
#       $DSH_HOME/profiles/web/cordis.patch.yml 中 dsh-lanmode 的 allow 列表，
#       宿主机网段不在镜像预置（127.0.0.0/8、192.168.0.0/16）内时也能放行。
#
# 用法：
#   自动探测：默认收集所有非 loopback IPv4，逐个转成 /24 网段注入
#   手动指定：docker run -e DSH_LAN_IP="192.168.1.5,10.0.0.3" ...
#
# 注意：
#   - 容器为 bridge 网络时 hostname -I 只能拿到 172.17.x.x 容器内网 IP，
#     并非宿主机局域网网段，此时建议用 -e DSH_LAN_IP 显式指定
#   - 幂等：目标网段已存在于 allow（或已被更大网段包含）时不会重复追加，
#     因此 entrypoint 每次启动重复执行是安全的
# =============================================================================
set -euo pipefail

PATCH_YML="$DSH_HOME/profiles/web/cordis.patch.yml"

if [ ! -f "$PATCH_YML" ]; then
  echo "[my-plugin-init] 未找到 ${PATCH_YML}，跳过注入"
  exit 0
fi

# ---- 1. 收集候选 IP ---------------------------------------------------------
# 优先级：环境变量 DSH_LAN_IP（逗号分隔多个）> 容器内自动探测
if [ -n "${DSH_LAN_IP:-}" ]; then
  IPS="${DSH_LAN_IP//,/ }"
  echo "[my-plugin-init] 使用 DSH_LAN_IP 指定的 IP: ${IPS}"
else
  IPS="$(hostname -I 2>/dev/null || true)"
  echo "[my-plugin-init] 自动探测到的 IP: ${IPS:-（无）}"
fi

# ---- 2. IP -> /24 网段 CIDR -------------------------------------------------
ip2int() {
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  echo $(( (a << 24) | (b << 16) | (c << 8) | d ))
}

WANTED=()
for ip in $IPS; do
  case "$ip" in
    *.*.*.*) : ;;        # 仅处理 IPv4（跳过 IPv6 / 空段）
    *) continue ;;
  esac
  case "$ip" in
    127.*) continue ;;   # 跳过 loopback
  esac
  cidr="$(awk -F. '{print $1"."$2"."$3".0/24"}' <<< "$ip")"
  WANTED+=("$cidr")
done

if [ "${#WANTED[@]}" -eq 0 ]; then
  echo "[my-plugin-init] 未发现可注入的局域网 IPv4，跳过（bridge 网络请用 -e DSH_LAN_IP 指定）"
  exit 0
fi

# ---- 3. 幂等过滤：已被 allow 现有网段覆盖的跳过 ------------------------------
contains() { # contains <外层CIDR> <内层CIDR>：内层已被外层包含时返回 0
  local outer=$1 inner=$2 om im shr
  case "$outer" in */*) om="${outer##*/}" ;; *) om=32 ;; esac
  case "$inner" in */*) im="${inner##*/}" ;; *) im=32 ;; esac
  if (( om > im )); then return 1; fi
  shr=$(( 32 - om ))
  (( ($(ip2int "${outer%%/*}") >> shr) == ($(ip2int "${inner%%/*}") >> shr) ))
}

EXISTING="$(grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}' "$PATCH_YML" 2>/dev/null || true)"

NEW=()
for cidr in "${WANTED[@]}"; do
  for e in $EXISTING; do
    if contains "$e" "$cidr"; then
      echo "[my-plugin-init] ${cidr} 已被 ${e} 覆盖，跳过"
      continue 2
    fi
  done
  NEW+=("$cidr")
done

if [ "${#NEW[@]}" -eq 0 ]; then
  echo "[my-plugin-init] allow 列表已覆盖所有网段，无需修改"
  exit 0
fi

# ---- 4. 注入到 dsh-lanmode 块的 allow 列表 ----------------------------------
awk -v ins="${NEW[*]}" '
  /- id: dsh-lanmode/        { inblock = 1 }
  /^ *- id:/ && !/dsh-lanmode/ { inblock = 0 }
  {
    print
    if (inblock && $0 ~ /^[ \t]+allow:[ \t]*$/) {
      n = split(ins, a, " ")
      for (i = 1; i <= n; i++) print "      - " a[i]
    }
  }
' "$PATCH_YML" > "${PATCH_YML}.tmp" && mv "${PATCH_YML}.tmp" "$PATCH_YML"

echo "[my-plugin-init] 已注入网段: ${NEW[*]} -> dsh-lanmode allow"
