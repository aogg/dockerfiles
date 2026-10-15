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

# ============================================================
# 可选：DSH_LLM_* 环境变量 → 自动生成自定义 OpenAI 兼容大模型配置
# 目标文件：$DSH_HOME/profiles/web/cordis.patch.yml（profile 用户层，dsh 每次启动都会加载）
# 生成的条目与 /root/.dsh/profiles/web/cordis.patch.yml 中的 llm-pi-ai 同构：
#   - id: llm-pi-ai
#     name: "@deepseek-ai/dsh-llm-pi-ai"
#     config:
#       providers:
#         <provider>:
#           apiKeyEnv: <env 变量名>
#           api: openai-completions
#           baseURL: <服务地址>
#           compat:
#             supportsDeveloperRole: false
#           models: [...]
#
# 环境变量：
#   DSH_LLM_BASE_URL        OpenAI 兼容服务地址（含 /v1）。与 DSH_LLM_MODELS 同时设置才启用本功能
#   DSH_LLM_MODELS          逗号分隔模型 id 列表，如 "glm-5.3-flash,gs/glm-5.3-flash"
#   DSH_LLM_PROVIDER_ID     可选，providers 映射键，默认 custom-openai
#   DSH_LLM_API             可选，协议类型，默认 openai-completions
#   DSH_LLM_API_KEY         可选，API Key 明文：只保留在容器环境变量里（不写入 yml），
#                           生成的 apiKeyEnv 指向 DSH_LLM_API_KEY 本身
#   DSH_LLM_API_KEY_ENV     可选，复用已有 Key 的环境变量名（DSH_LLM_API_KEY 未设置时生效）
#   DSH_LLM_CONTEXT_WINDOW  可选，为所有模型追加 contextWindow（正整数，如 924000）
#   DSH_LLM_MAX_TOKENS      可选，为所有模型追加 maxTokens（正整数，如 101072）
#
# 幂等（多次重启 / 已配置过不再生成）：
#   cordis.patch.yml 已存在 "id: llm-pi-ai"（手动配置或上次已生成）即跳过，绝不重复追加；
#   如需按新环境变量重新生成，先删除 yml 里 "# >>> dsh-env-llm" ～ "# <<< dsh-env-llm" 段再重启。
# ============================================================
if [ -n "${DSH_LLM_BASE_URL:-}" ] || [ -n "${DSH_LLM_MODELS:-}" ]; then
  DSH_LLM_PATCH="$DSH_HOME/profiles/web/cordis.patch.yml"

  # YAML 值单引号包裹（内部单引号翻倍转义），避免特殊字符破坏 yml 结构
  dsh_llm_sq() { printf "'%s'" "${1//\'/\'\'}"; }

  if [ -z "${DSH_LLM_BASE_URL:-}" ] || [ -z "${DSH_LLM_MODELS:-}" ]; then
    echo "[dsh-env-llm] 警告：DSH_LLM_BASE_URL 与 DSH_LLM_MODELS 需同时设置才生成，本次跳过"
  elif [ -f "$DSH_LLM_PATCH" ] && grep -q 'id: llm-pi-ai' "$DSH_LLM_PATCH"; then
    echo "[dsh-env-llm] $DSH_LLM_PATCH 已存在 llm-pi-ai 配置（已配置过/上次已生成），跳过"
  else
    LLM_PROVIDER="${DSH_LLM_PROVIDER_ID:-custom-openai}"
    LLM_API="${DSH_LLM_API:-openai-completions}"
    mkdir -p "$(dirname "$DSH_LLM_PATCH")"
    [ -f "$DSH_LLM_PATCH" ] || printf '# DeepSeek Harness web profile 用户层配置\n' > "$DSH_LLM_PATCH"
    {
      printf '\n'
      printf '# >>> dsh-env-llm：本段由 docker-entrypoint.sh 依据 DSH_LLM_* 环境变量自动生成\n'
      printf '# 幂等：已存在 id: llm-pi-ai 即不再生成；删除本段（含首尾标记行）后重启可按新环境变量重新生成\n'
      printf -- '- id: llm-pi-ai\n'
      printf '  name: "@deepseek-ai/dsh-llm-pi-ai"\n'
      printf '  config:\n'
      printf '    providers:\n'
      printf '      %s:\n' "$(dsh_llm_sq "$LLM_PROVIDER")"
      # API Key：优先 DSH_LLM_API_KEY（Key 本体留在容器 env，不落盘）；否则复用 DSH_LLM_API_KEY_ENV
      if [ -n "${DSH_LLM_API_KEY:-}" ]; then
        printf '        apiKeyEnv: DSH_LLM_API_KEY\n'
      elif [ -n "${DSH_LLM_API_KEY_ENV:-}" ]; then
        printf '        apiKeyEnv: %s\n' "$(dsh_llm_sq "$DSH_LLM_API_KEY_ENV")"
      fi
      printf '        api: %s\n' "$LLM_API"
      printf '        baseURL: %s\n' "$(dsh_llm_sq "$DSH_LLM_BASE_URL")"
      cat <<'YML'
        # 智谱 GLM 不接受 developer 角色（400 code 1214 角色信息不正确）；
        # 自建代理 URL 无法被 pi-ai 识别为 zai，必须显式关闭 developer 角色
        compat:
          supportsDeveloperRole: false
        models:
YML
      IFS=',' read -ra LLM_MODEL_LIST <<< "$DSH_LLM_MODELS"
      for LLM_M in "${LLM_MODEL_LIST[@]}"; do
        # 去首尾空白
        LLM_M="${LLM_M#"${LLM_M%%[![:space:]]*}"}"
        LLM_M="${LLM_M%"${LLM_M##*[![:space:]]}"}"
        [ -n "$LLM_M" ] || continue
        printf '          - id: %s\n' "$(dsh_llm_sq "$LLM_M")"
        printf '            name: %s\n' "$(dsh_llm_sq "$LLM_M")"
        if [ -n "${DSH_LLM_CONTEXT_WINDOW:-}" ] && [[ "$DSH_LLM_CONTEXT_WINDOW" =~ ^[0-9]+$ ]]; then
          printf '            contextWindow: %s\n' "$DSH_LLM_CONTEXT_WINDOW"
        fi
        if [ -n "${DSH_LLM_MAX_TOKENS:-}" ] && [[ "$DSH_LLM_MAX_TOKENS" =~ ^[0-9]+$ ]]; then
          printf '            maxTokens: %s\n' "$DSH_LLM_MAX_TOKENS"
        fi
        cat <<'YML'
            reasoningEfforts:
              off: null
              low: low
              medium: medium
              high: high
              max: max
YML
      done
      printf '# <<< dsh-env-llm\n'
    } >> "$DSH_LLM_PATCH"
    echo "[dsh-env-llm] 已生成自定义模型配置 → $DSH_LLM_PATCH (provider: $LLM_PROVIDER, api: $LLM_API)"
  fi
  unset -f dsh_llm_sq
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