FROM node:24-slim

# 基础工具：
# - git          ：pnpm 解析 Git 依赖必需（保留，部分插件可能仍引用 Git 仓库）
# - ca-certificates / curl ：健康检查与基础排障
# - python3/make/g++ ：node-gyp 编译工具链（ssh2 等可选原生绑定、node-pty 场景）
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates curl python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

# pnpm：`dsh plugin` 将参数原样转发给 pnpm（profile 插件管理必需）
RUN npm install -g pnpm

# DeepSeek Harness CLI（原生模块 node-pty/koffi 等需 allow-scripts 显式放行构建）
# @see https://github.com/deepseek-ai/deepseek-harness
RUN npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh

# 预置 web profile 的 pnpm 配置（dsh plugin 首次初始化时会跳过已存在的文件）：
#   nodeLinker: hoisted / autoInstallPeers: false —— dsh 官方 profile 模板配置
#   minimumReleaseAge: 0 —— 避开 pnpm>=11 的新包发布年龄门禁（否则静默装到旧版插件）
#   allowBuilds —— 放行原生构建脚本：
#     cloudflared/cpu-features/ssh2 由 @linxin666/dsh-web-ui-all 全家桶带入
#     @nanmicoder/dsh-agent-teams 为 npm 包，无需 Git 依赖构建

ENV DSH_HOME=/root/.dsh \
    DSH_PORT=3080
RUN mkdir -p $DSH_HOME/profiles/web \
    && printf '%s\n' \
        'packages:' \
        '  - .' \
        '' \
        'nodeLinker: hoisted' \
        'autoInstallPeers: false' \
        'minimumReleaseAge: 0' \
        'allowBuilds:' \
        '  cloudflared: true' \
        '  cpu-features: true' \
        '  ssh2: true' \
        '  node-pty: true' \
        '  koffi: true' \
        > $DSH_HOME/profiles/web/pnpm-workspace.yaml


# 初始化 web profile 并安装三个插件：
#   1) dsh-usage-stats                —— token 用量统计（npm）
#      https://github.com/lanlandeli/dsh-usage-stats
#   2) @linxin666/dsh-web-ui-all      —— dsh-web-ui 全家桶（npm 聚合包）
#      https://github.com/zhu1090093659/dsh-web-ui
#   3) @nanmicoder/dsh-agent-teams    —— 多模型 agent 小队（npm）
#      https://github.com/NanmiCoder/dsh-agent-teams
RUN dsh plugin --profile web add dsh-usage-stats @linxin666/dsh-web-ui-all @nanmicoder/dsh-agent-teams \
    && dsh --profile web --dump-config | grep -E "agent-teams|@nanmicoder"

# profile 用户层：webserver 监听 0.0.0.0
# （dsh 的 CLI 故意拒绝 `--host 0.0.0.0`，只能通过 profile 配置层覆盖；
#   容器网络由 --expose/端口映射控制暴露面）
COPY cordis.patch.yml $DSH_HOME/profiles/web/cordis.patch.yml

COPY docker-entrypoint.sh /docker-entrypoint.sh
# RUN chmod +x /docker-entrypoint.sh

RUN mv $DSH_HOME/profiles/web $DSH_HOME/profiles/web_bak

EXPOSE 3080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS --noproxy '*' "http://127.0.0.1:${DSH_PORT}/" >/dev/null || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]