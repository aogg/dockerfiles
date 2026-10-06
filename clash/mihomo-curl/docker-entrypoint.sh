#!/usr/bin/env ash

# 根据别人的yaml，启动 mihomo
#
# URL 环境变量支持占位符模板:
#   [Y]   -> 4位年份, 如 2026
#   [m]   -> 2位月份, 如 09
#   [d]   -> 2位日期, 如 29
#   [int] -> 自增整数, 从 0 开始
#            每成功下载一个 URL 就启动一个 mihomo 实例,
#            混合端口从 7890 起随实例自增 (7890, 7891, ...),
#            API(external-controller) 端口从 9090 起自增;
#            curl 下载重试 3 次, 3 次全部失败则停止自增。
# 示例:
#   URL=https://clashnode.github.io/uploads/[Y]/[m]/[int]-[Y][m][d].yaml
#   会展开为 .../uploads/2026/09/0-20260929.yaml、.../1-20260929.yaml 等
#
# START_DATE 环境变量(可选, YYYY-MM-DD 或 YYYYMMDD):
#   日期回溯的最早日期。第 0 个 [int] 按 今天 -> START_DATE 倒序逐日尝试,
#   命中某天即锁定该天, 后续 [int] 只在锁定的日期上自增, 不再从今天重扫;
#   锁定日期无数据(或整个日期范围都无数据)时, 才停止自增。
#   不设置时仅使用今天, 无回溯。
#
# GITHUB_PROXY 环境变量(可选):
#   github 相关 URL 的代理前缀, 默认 https://hk.gh-proxy.org/, 置空则禁用。
#   配置中 geox-url 以及 rule-providers / proxy-providers 的 url 若以
#   https://(*.|)github(usercontent)?.com 开头, 会自动加上该前缀, 例:
#   https://raw.githubusercontent.com/xxx.yaml
#     -> https://hk.gh-proxy.org/https://raw.githubusercontent.com/xxx.yaml
#   配置缺少 geox-url 时自动写入默认值(jsdelivr CDN, 可直连)。

configDir="/root/.config/mihomo"
configFilePath="$configDir/config.yaml"
PORT="${PORT:-7890}"
CTRL_PORT_BASE="${CTRL_PORT_BASE:-9090}"
GITHUB_PROXY="${GITHUB_PROXY:-https://hk.gh-proxy.org/}"

# 确保目录存在
mkdir -p "$configDir"

# --- 日期与 URL 模板 ---

DATE_Y=""
DATE_m=""
DATE_d=""
TODAY_STR=""
START_STR=""
TODAY_EP=""
START_EP=""
LOCKED_EP=""

# 设置 $1=YYYYMMDD 到 DATE_Y/m/d
set_date_parts() {
  DATE_Y=$(echo "$1" | cut -c1-4)
  DATE_m=$(echo "$1" | cut -c5-6)
  DATE_d=$(echo "$1" | cut -c7-8)
}

# 计算日期范围: START_DATE(默认今天) ~ 今天 (epoch 秒, 供倒序回溯)
refresh_date_range() {
  # 每轮(首次启动/每日更新)重置锁定日期, 重新从今天开始扫描
  LOCKED_EP=""
  TODAY_STR=$(date +%Y%m%d)
  if [ -n "$START_DATE" ]; then
    START_STR=$(echo "$START_DATE" | tr -d '/-' | cut -c1-8)
  else
    START_STR="$TODAY_STR"
  fi
  TODAY_EP=$(date -d "${TODAY_STR}0000" +%s)
  START_EP=$(date -d "${START_STR}0000" +%s 2>/dev/null)
  if [ -z "$START_EP" ] || [ "$START_EP" -gt "$TODAY_EP" ]; then
    echo "警告: START_DATE='${START_DATE}' 无效或晚于今天, 忽略, 仅使用今天"
    START_STR="$TODAY_STR"
    START_EP="$TODAY_EP"
  fi
  # 默认日期为今天
  set_date_parts "$TODAY_STR"
}

# 按 日期: 今天 -> START_DATE 倒序尝试下载 (每天 curl 重试 3 次), 命中即锁定该日期;
# 已锁定日期时, 后续 [int] 只尝试锁定日期, 不再回溯
# $1=int值, $2=输出文件
fetch_with_date_fallback() {
  fbInt="$1"
  fbOut="$2"
  if [ -n "$LOCKED_EP" ]; then
    # 已锁定: 只试锁定日期这一天
    ep="$LOCKED_EP"
    lastEp="$LOCKED_EP"
  else
    # 未锁定: 从今天倒序扫到 START_DATE
    ep="$TODAY_EP"
    lastEp="$START_EP"
  fi
  while [ "$ep" -ge "$lastEp" ]; do
    fbDay=$(date -d "@$ep" +%Y%m%d)
    set_date_parts "$fbDay"
    realUrl=$(build_url "$URL" "$fbInt")
    echo "尝试日期 ${DATE_Y}-${DATE_m}-${DATE_d}: ${realUrl}"
    if download_with_retry "$realUrl" "$fbOut"; then
      echo "命中日期 ${DATE_Y}-${DATE_m}-${DATE_d}"
      LOCKED_EP="$ep"
      return 0
    fi
    rm -f "$fbOut"
    ep=$((ep - 86400))
  done
  if [ -n "$LOCKED_EP" ]; then
    set_date_parts "$(date -d "@$LOCKED_EP" +%Y%m%d)"
    echo "错误: 锁定日期 ${DATE_Y}-${DATE_m}-${DATE_d} 无实例 ${fbInt} 的数据"
  else
    echo "错误: 从 ${TODAY_STR} 回溯到 ${START_STR} 均无数据"
  fi
  return 1
}

# 替换 URL 模板中的占位符: $1=URL模板, $2=int值
build_url() {
  echo "$1" | sed -e "s/\[Y\]/$DATE_Y/g" \
                   -e "s/\[m\]/$DATE_m/g" \
                   -e "s/\[d\]/$DATE_d/g" \
                   -e "s/\[int\]/$2/g"
}

# --- 下载(重试3次) ---

# $1=url, $2=输出文件; 3次全部失败返回 1
download_with_retry() {
  dlUrl="$1"
  dlOut="$2"
  dlTry=1
  while [ "$dlTry" -le 3 ]; do
    if curl -fL --connect-timeout 10 --max-time 120 -o "$dlOut" "$dlUrl"; then
      return 0
    fi
    echo "警告: 下载失败(第 ${dlTry}/3 次): $dlUrl"
    dlTry=$((dlTry + 1))
    sleep 2
  done
  echo "错误: 3 次下载均失败: $dlUrl"
  return 1
}

# --- 配置处理 ---

# 给配置中 github 开头的 URL 加 GITHUB_PROXY 前缀:
# 覆盖 geox-url 的各值, 以及 rule-providers / proxy-providers 的 url
# (已加过前缀的 URL 开头是代理域名, 不会再次匹配, 天然防重复;
#   字段缺失时跳过, 不会自动创建空 [] 导致 mihomo 报
#   cannot unmarshal !!seq into map[string]map[string]interface {})
add_gh_proxy() {
  gpFile="$1"
  [ -n "$GITHUB_PROXY" ] || { echo "GITHUB_PROXY 为空, 跳过 github 代理前缀"; return 0; }
  echo "为 github 相关 URL 添加代理前缀: ${GITHUB_PROXY}"
  for gpKey in geox-url rule-providers proxy-providers; do
    gpTag=$(yq ".$gpKey | tag" "$gpFile")
    if [ "$gpTag" = "!!seq" ]; then
      # 原配置自带空 [] 时删除, 避免 mihomo 解析失败
      echo "警告: ${gpKey} 为空序列, 删除该字段"
      yq -i "del(.$gpKey)" "$gpFile"
      continue
    fi
    [ "$gpTag" = "!!map" ] || { echo "跳过 ${gpKey} (不存在)"; continue; }
    if [ "$gpKey" = "geox-url" ]; then
      gpPath=".$gpKey[]"
    else
      gpPath=".$gpKey[].url"
    fi
    yq -i '('"$gpPath"' | select(tag == "!!str" and test("^https://([^/]+\\.)?github(usercontent)?\\.com/"))) |= "'"$GITHUB_PROXY"'" + .' "$gpFile"
  done
}

# 对单个配置文件应用 yq 修改
# $1=配置文件路径  $2=mixed-port  $3=external-controller(为空则不设置)
process_config() {
  cfgFile="$1"
  cfgPort="$2"
  cfgCtrl="$3"

  # 设置混合端口
  echo "设置 mixed-port 为 ${cfgPort}"
  yq -i ".mixed-port = ${cfgPort}" "$cfgFile"

  if [ -n "$cfgCtrl" ]; then
    echo "设置 external-controller 为 ${cfgCtrl}"
    yq -i ".external-controller = \"${cfgCtrl}\"" "$cfgFile"
    # 删除可能与其它实例冲突的端口配置
    yq -i 'del(.port, .socks-port, .redir-port, .tproxy-port)' "$cfgFile"
  fi

  # 缺少 geox-url(或值非 map, 如空 [])时写入默认值 (jsdelivr CDN, 无需代理)
  if [ "$(yq '.geox-url | tag' "$cfgFile")" != "!!map" ]; then
    echo "未配置 geox-url, 写入默认值"
    yq -i '.geox-url = {
      "mmdb": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.metadb",
      "geoip": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat",
      "geosite": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
    }' "$cfgFile"
  fi

  # 为 github 开头的 URL 添加代理前缀 (geox-url / rule-providers / proxy-providers)
  add_gh_proxy "$cfgFile"

  # 使用 yq 根据环境变量修改配置
  for env in $(printenv); do
    key=$(echo $env | cut -d= -f1)
    raw_val=$(echo $env | cut -d= -f2- | sed "s/^'\(.*\)'/\\1/g")

    if echo "$key" | grep -q "^CONFIG_YQ_"; then
      echo "raw_val=$raw_val"
      # 在第一个=切分成 yq表达式路径 和 值
      yq_path="${raw_val%%=*}"
      yq_value="${raw_val#*=}"
      echo "  yq路径: $yq_path"
      echo "  设置值: $yq_value"

      echo "应用 yq 配置: $yq_path => $yq_value"
      if [ "$yq_value" = "null" ]; then
          # 值为null，删除该key
          echo "👉 值为null，执行删除: $yq_path"
          yq -i "del($yq_path)" "$cfgFile"
      elif [ "$yq_value" = "true" ] || [ "$yq_value" = "false" ]; then
        yq -i "$yq_path = $yq_value" "$cfgFile"
      else
          # 普通赋值，去掉你原来强制加\"$yq_value\"，避免bool/object被转字符串
          yq -i "$yq_path = \"$yq_value\"" "$cfgFile"
      fi

      echo "✅ 应用完成 $yq_path = $yq_value"
      echo "应用 yq 配置完成: $key"
    fi
  done

  # 检查并创建 'load' 代理组
  echo "检查 'load' 代理组..."
  load_group_exists=$(yq '.proxy-groups[] | select(.name == "load") | length' "$cfgFile")

  if [ -n "$load_group_exists" ] && [ "$load_group_exists" -gt 0 ]; then
      echo "'load' 代理组已存在，跳过创建。"
  else
      echo "创建 'load' 代理组..."

      # proxies_from_select_node=$(yq -o y '.proxies[].name' $cfgFile" | tr -d '\n')

      echo "从 '🔰 选择节点' 提取的代理: $proxies_from_select_node"
      yq -i '.proxy-groups += [{"name": "load", "type": "load-balance", "strategy": "round-robin", "url": "http://www.gstatic.com/generate_204", "interval": 300, "health-check": {"enable": true, "interval": 60, "url": "http://www.gstatic.com/generate_204", "timeout": 10}}]' "$cfgFile"

    # 直接在 yq 内部取所有节点名，避免 shell 拼接表达式
    yq -i '(.proxy-groups[] | select(.name == "load")).proxies = (.proxies | map(.name))' "$cfgFile"

      echo "将 'load' 添加到 GLOBAL 组..."
      global_index=$(yq '.proxy-groups | to_entries | .[] | select(.value.name == "GLOBAL") | .key' "$cfgFile")
      [ -n "$global_index" ] && yq -i ".proxy-groups[${global_index}].proxies = [\"load\"] + .proxy-groups[${global_index}].proxies" "$cfgFile"
  fi

  echo "配置文件处理完成: $cfgFile"
  return 0
}

# --- 多实例管理 ---

instance_dir() { echo "$configDir/inst$1"; }
pid_file() { echo "/tmp/mihomo-inst$1.pid"; }

stop_instance() {
  pf=$(pid_file "$1")
  if [ -f "$pf" ]; then
    kill "$(cat "$pf")" 2>/dev/null
    rm -f "$pf"
  fi
}

# 启动(或重启)实例 $1
start_instance() {
  instIdx="$1"
  instDir=$(instance_dir "$instIdx")
  mkdir -p "$instDir"
  stop_instance "$instIdx"
  sleep 1
  echo /mihomo -d "$instDir" -f "$instDir/config.yaml" &
  /mihomo -d "$instDir" -f "$instDir/config.yaml" &
  echo $! > "$(pid_file "$instIdx")"
  echo "实例 ${instIdx} 已启动, PID: $(cat "$(pid_file "$instIdx")"), 端口: $((PORT + instIdx))"
}

# 后台选择代理
select_proxies_for() {
  cfgSel="$1"
  if [ -f "/proxies-select.sh" ]; then
    (sleep 5 && /proxies-select.sh "$cfgSel") &
  fi
}

# 多实例模式: 按 [int] 自增展开 URL 并逐一启动;
# 第 0 个 [int] 按 今天->START_DATE 倒序找数据, 命中即锁定该日期,
# 后续 [int] 只在锁定日期自增, 该日期无数据才停止自增
start_all_instances() {
  refresh_date_range
  i=0
  summary=""
  while :; do
    instDir=$(instance_dir "$i")
    mkdir -p "$instDir"
    tmpCfg="$instDir/config.yaml.tmp"
    echo "-----------------------------------------"
    if ! fetch_with_date_fallback "$i" "$tmpCfg"; then
      rm -f "$tmpCfg"
      if [ -f "$instDir/config.yaml" ]; then
        echo "实例 ${i}: 无可用数据, 沿用旧配置继续运行"
      fi
      echo "[int] 自增结束, 共启动 ${i} 个实例"
      break
    fi
    echo "实例 ${i}: 使用 ${DATE_Y}-${DATE_m}-${DATE_d} 的配置"
    mv "$tmpCfg" "$instDir/config.yaml"
    process_config "$instDir/config.yaml" "$((PORT + i))" "0.0.0.0:$((CTRL_PORT_BASE + i))"
    start_instance "$i"
    select_proxies_for "$instDir/config.yaml"
    # 记录汇总信息(读取最终配置中的实际 API 端口)
    instCtrl=$(yq '.external-controller' "$instDir/config.yaml")
    [ "$instCtrl" = "null" ] && instCtrl="-"
    summary="${summary}实例 ${i} | 代理端口 $((PORT + i)) | API ${instCtrl} | ${realUrl} | 生成后yaml文件路径 ${instDir}/config.yaml
"
    i=$((i + 1))
  done

  # 自增结束后汇总: 哪些 URL 有效, 对应启动的端口
  if [ -n "$summary" ]; then
    echo "========================================="
    if [ -n "$LOCKED_EP" ]; then
      echo "汇总: 锁定日期 $(date -d "@$LOCKED_EP" +%Y-%m-%d), 共 ${i} 个有效实例:"
    else
      echo "汇总: 共 ${i} 个有效实例:"
    fi
    echo "$summary"
  fi
}

# --- 单实例模式 ---

update_single() {
  refresh_date_range

  # 1. 下载配置文件 (按 今天->START_DATE 倒序尝试)
  if [ -n "${URL}" ]; then
    if ! fetch_with_date_fallback 0 /mihomo-config.yaml; then
      echo "错误：下载配置文件失败！"
      return 1
    fi
    echo "使用 ${DATE_Y}-${DATE_m}-${DATE_d} 的配置"
    cp /mihomo-config.yaml $configFilePath
  else
    echo "警告：未提供 URL 环境变量，跳过下载。"
    # 如果本地没有配置文件，则退出
    if [ ! -f "$configFilePath" ]; then
        echo "错误：未找到配置文件，并且未提供 URL。"
        return 1
    fi
  fi

  process_config "$configFilePath" "$PORT" ""
  return 0
}

# --- 主程序 ---

# URL 含 [int] 占位符 => 多实例模式
is_multi=0
case "${URL:-}" in
  *"[int]"*) is_multi=1 ;;
esac

# 首次启动时更新配置
echo "首次启动，执行配置..."
if [ "$is_multi" = "1" ]; then
  echo "URL 含 [int] 占位符, 启用多实例模式"
  start_all_instances
  if ! ls /tmp/mihomo-inst*.pid >/dev/null 2>&1; then
    echo "首次配置失败(没有任何实例启动)，容器将退出。"
    exit 1
  fi
else
  update_single
  if [ $? -ne 0 ]; then
    echo "首次配置失败，容器将退出。"
    exit 1
  fi

  # 启动 mihomo
  echo "启动 mihomo 服务..."
  /mihomo &
  CLASH_PID=$!
  select_proxies_for "$configFilePath"
fi

# 启动定时更新循环
echo "启动每日定时更新任务..."
while true; do
  # 等待 24 小时
  sleep 86400

  echo "========================================="
  echo "开始每日定时更新..."

  if [ "$is_multi" = "1" ]; then
    # 重新按当天日期展开所有 URL, 成功的实例重启, 失败的沿用旧配置
    # (第 0 个就下载失败时不关闭/重启任何实例, 也不更新任何配置)
    start_all_instances
  else
    # 更新配置; 一个都没下载成功则不更新配置、不重启 mihomo
    if update_single; then
      # 重启 Clash
      echo "重启 mihomo 服务以应用新配置..."
      kill $CLASH_PID
      sleep 1
      /mihomo &
      CLASH_PID=$!
      select_proxies_for "$configFilePath"
      echo "mihomo 已重启, 新 PID: $CLASH_PID"
    else
      echo "下载配置全部失败，跳过更新，mihomo 继续运行 (PID: $CLASH_PID)"
    fi
  fi
  echo "========================================="
done
