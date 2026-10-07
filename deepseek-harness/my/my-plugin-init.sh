#!/usr/bin/env bash
# =============================================================================
# my-plugin-init.sh —— dsh-lanmode 局域网 IP 注入 + dsh-remote-auth 门禁重建
#
# 由 docker-entrypoint.sh 启动时执行：$DSH_HOME/docker-entrypoint-init-sh/*.sh
# 作用（两件事，幂等，entrypoint 每次启动重复执行是安全的）：
#   1) 把当前局域网 IP 所在的 /24 网段追加进
#      $DSH_HOME/profiles/web/cordis.patch.yml 中 dsh-lanmode 的 allow 列表，
#      宿主机网段不在镜像预置（127.0.0.0/8、192.168.0.0/16）内时也能放行；
#   2) 重建同文件中 dsh-remote-auth 的门禁配置块（allowedSubnets /
#      allowedAuthorities / pin）：每次启动先删旧块，再按当前 env 与探测到的
#      网段重新生成——手动改该块会被覆盖，请一律通过下面的 env 配置。
#
# 环境变量：
#   DSH_LAN_IP                   逗号分隔多个 IP，优先于容器内自动探测（lanmode 用）
#   DSH_REMOTE_AUTH_AUTHORITIES  逗号分隔的 Host 白名单（裸主机名或 host:port），
#                                写入 allowedAuthorities；不设 = 空表（仅回环放行）
#   DSH_REMOTE_AUTH_PIN          8 位字母数字 PIN，写入 pin；不设或为空 = 关闭 PIN 门禁
#                                （仅支持 8 位字母数字，值含双引号等特殊字符不支持）
#
# 注意：
#   - 容器为 bridge 网络时 hostname -I 只能拿到 172.17.x.x 容器内网 IP，
#     并非宿主机局域网网段，此时建议用 -e DSH_LAN_IP 显式指定
#   - 幂等（lanmode）：目标网段已存在于 allow（或已被更大网段包含）时不会重复追加
#   - 幂等（remote-auth）：相同 env+IPs 两次执行产出完全一致，env 变更后重启即生效
#   - 顺序：必须先 lanmode 后 remote-auth——lanmode 的幂等查重是对全文件 CIDR 做
#     grep，若 remote-auth 块先写入，lanmode 会误判网段已存在而跳过注入
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

# ---- 3. lanmode 注入（原 3、4 节逻辑不变，仅 WANTED 非空时执行）-------------
# 未发现可注入 IPv4 时只跳过 lanmode 注入、不退出脚本：
# 后面的 remote-auth 节不依赖 WANTED 非空，必须继续执行
if [ "${#WANTED[@]}" -eq 0 ]; then
  echo "[my-plugin-init] 未发现可注入的局域网 IPv4，跳过 lanmode 注入（bridge 网络请用 -e DSH_LAN_IP 指定）"
else
  # ---- 3.1 幂等过滤：已被 allow 现有网段覆盖的跳过 ----------------------------
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

  # ---- 3.2 注入到 dsh-lanmode 块的 allow 列表 ---------------------------------
  if [ "${#NEW[@]}" -eq 0 ]; then
    echo "[my-plugin-init] allow 列表已覆盖所有网段，无需修改"
  else
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
  fi
fi

# ---- 4. dsh-remote-auth：重建门禁配置块 -------------------------------------
# 每次启动先删旧块，再按当前 env/探测网段重建（手动改该块会被覆盖，请用 env 配置）
# 必须位于 lanmode 注入之后执行（顺序原因见头部注释）

# 4.1 删除已有的 - id: dsh-remote-auth 整块：从 ^- id: dsh-remote-auth 行起
#     跳过，直到下一个 ^- id: 行或 EOF，其余行原样保留；同时去掉文件末尾多余
#     空行，保证追加块前恰有一个空行（幂等，不随启动次数累积空行）
awk '
  /^- id: dsh-remote-auth/ { skip = 1; next }
  skip && /^- id:/         { skip = 0 }
  skip                     { next }
  { lines[++n] = $0 }
  END {
    while (n > 0 && lines[n] ~ /^[ \t]*$/) n--
    for (i = 1; i <= n; i++) print lines[i]
  }
' "$PATCH_YML" > "${PATCH_YML}.tmp" && mv "${PATCH_YML}.tmp" "$PATCH_YML"

# 4.2 子网白名单：回环恒放行 + WANTED 去重后的各 /24（WANTED 为空则仅回环）
SUBNETS=("127.0.0.0/8")
if [ "${#WANTED[@]}" -gt 0 ]; then
  for cidr in "${WANTED[@]}"; do
    dup=0
    for s in "${SUBNETS[@]}"; do
      if [ "$s" = "$cidr" ]; then dup=1; break; fi
    done
    if [ "$dup" -eq 0 ]; then SUBNETS+=("$cidr"); fi
  done
fi

# 4.3 域名白名单：DSH_REMOTE_AUTH_AUTHORITIES 按逗号切分（容忍空格）；空则内联空表
AUTHS=()
if [ -n "${DSH_REMOTE_AUTH_AUTHORITIES:-}" ]; then
  read -r -a RAW_AUTHS <<< "${DSH_REMOTE_AUTH_AUTHORITIES//,/ }"
  if [ "${#RAW_AUTHS[@]}" -gt 0 ]; then
    for entry in "${RAW_AUTHS[@]}"; do
      if [ -n "$entry" ]; then
        AUTHS+=("$entry")
      fi
    done
  fi
fi

# 4.4 PIN：不设或为空 = 关闭；恒以双引号输出（仅支持 8 位字母数字）
PIN="${DSH_REMOTE_AUTH_PIN:-}"

# 4.5 文件末尾追加新块（块前先补一个空行，缩进与 lanmode 块完全一致：
#     - id: 顶格 / config: 2 空格 / 标量键 4 空格 / 列表项 6 空格）
{
  printf '%s\n' '' \
    '- id: dsh-remote-auth' \
    '  config:' \
    '    allowedSubnets:'
  for cidr in "${SUBNETS[@]}"; do
    printf '%s\n' "      - ${cidr}"
  done
  if [ "${#AUTHS[@]}" -eq 0 ]; then
    printf '%s\n' '    allowedAuthorities: []'
  else
    printf '%s\n' '    allowedAuthorities:'
    for entry in "${AUTHS[@]}"; do
      printf '%s\n' "      - ${entry}"
    done
  fi
  printf '%s\n' "    pin: \"${PIN}\""
} >> "$PATCH_YML"

# 4.6 日志（不回显 PIN 值）
if [ -n "$PIN" ]; then
  PIN_STATE="已启用"
else
  PIN_STATE="关闭"
fi
echo "[my-plugin-init] dsh-remote-auth 门禁已重建: 子网 ${#SUBNETS[@]} 个 / 域名 ${#AUTHS[@]} 个 / PIN ${PIN_STATE}"
