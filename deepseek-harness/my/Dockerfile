

ARG ARGS_FROM=latest

FROM adockero/deepseek-harness:${ARGS_FROM}


# 基础镜像把初始化模板整体放在 ${DSH_HOME}_bak（entrypoint 首次启动拷回 $DSH_HOME），
# 构建期 $DSH_HOME 不存在，需先从模板恢复，定制完成后再 mv 回 ${DSH_HOME}_bak
RUN mkdir -p ${DSH_HOME}_bak/profiles/web \
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
        > ${DSH_HOME}_bak/profiles/web/pnpm-workspace.yaml


# 初始化 web profile 并预装插件（2026-10-28 第二版：自有插件一律走你的 GitHub 仓库
# pnpm github 安装，替换 npm 上的上游版本；第三方插件仍走 npm 并钉住运行版本）：
#   —— 第三方（npm，钉运行版）：
#   1)  @goodandready/dsh-lanmode@0.8.13 —— 局域网直连（社区 Alpha）
#       烘焙 cordis.patch.yml：自签名CA + mDNS + PWA + unlockPrivileged，
#       解决局域网访问时 settings are unavailable in this browser。
#       direct 模式直连 3080；CA 证书：https://<内网IP>:3080/dsh-lanmode/ca.crt
#   2)  dshmarket@1.66.7                —— 插件市场（npm 包名是 dshmarket，没有 dsh-market）
#   3)  dsh-prompt-history@1.2.15       —— 类 shell 输入历史(↑/↓ 召回)+终端式复制粘贴
#   4)  dsh-remote-auth@0.1.2 -w        —— 远程授权页（/mobile-auth 链接/二维码铸造会话）
#       运行期门禁由 my-plugin-init.sh 依据 env 初始化：
#       DSH_REMOTE_AUTH_AUTHORITIES / DSH_REMOTE_AUTH_PIN / 网段自动探测
#   5)  dsh-message-copy-enhance@0.2.1  —— 消息复制增强
#   6)  @changfenhuang/dsh-genui@0.14.0 —— GenUI 结构化界面
#   7)  dsh-mnemon@0.5.35               —— 记忆系统
#   8)  dsh-context@0.77.0              —— 上下文
#   9)  @xmanrui/dsh-im@5.6.0           —— IM
#   10) dsh-opencode-connect            —— opencode 连接插件（npm 0.1.0）
#   —— 自有仓库（github 安装，随你 push 自动更新；当前均落后本地开发版）：
#   11) github:aogg/DSH-better-sidebar#main —— 增强侧边栏
#       origin/main=3db681e，落后本地 4 提交（ssh-workspace 支持、工作区独立链接/
#       专注模式未包含）；仓库带 prepare=tsdown，pnpm 安装时自动构建，实测通过
#   12) github:aogg/dsh-ssh-workspace#main —— 远程 SSH 工作区
#       落后本地 4 提交（Windows 方言分派等 3 个修复）；lib 已提交免构建
#   13) github:aogg/dsh-resume-on-restart#master —— 重启后自动恢复会话
#       落后本地 14 提交；lib 已提交免构建
#   14) dsh-git-idea —— git 集成：下方 RUN 已克隆 origin/main（d05b2d1，落后本地
#       31 提交）构建出 dist/，此处以本地目录安装（该仓库无 prepare，github 直装
#       拿不到 dist 不可用）
#   另有：opencode-ai 全局 CLI（下方 RUN npm install -g opencode-ai）
#
# 有意不预装（2026-10-28 口径）：
#   - dsh-usage-stats / dsh-power-button：运行环境已禁用/已移除，放弃
#   - dsh-ao-local / dsh-rules-auto / dsh-ao-conversation-tab / dsh-ao-client-request-log：
#     my-ai 本地 link 插件，按要求不预装
#   - dsh-reply-model-badge：仅本地仓库（GitHub 无此仓库、无 npm 包），无从 github 安装
#   - dsh-web-mobile / dsh-connect-sensenova-token-plan：运行环境 disabled，不装



# 局域网网段初始化脚本（entrypoint 每次启动执行 docker-entrypoint-init-sh/*.sh）：
# 启动时把当前 IP 所在 /24 网段自动追加进 cordis.patch.yml 的 dsh-lanmode allow，
# 除 lanmode 网段外，同时重建 dsh-remote-auth 的门禁配置（域名白名单/PIN/子网，依 env）
# 幂等可重复执行；容器 bridge 网络下探测到的是容器内网 IP，
# 可用 docker run -e DSH_LAN_IP="192.168.1.5,10.0.0.3" 显式指定
# init 脚本必须放进模板 ${DSH_HOME}_bak：若放在 $DSH_HOME，
# VOLUME 首次挂载时目录非空，entrypoint 会误判"已初始化"而跳过模板拷贝
COPY my/my-plugin-init.sh ${DSH_HOME}_bak/docker-entrypoint-init-sh/


# opencode CLI 全局安装
RUN npm install -g opencode-ai \
    && npm install -g @tencent-ai/codebuddy-code


# dsh-git-idea 需先构建：该仓库无 prepare 钩子，pnpm 的 github 依赖安装时不会自动
# 跑 build，直接 github: 安装会拿到没有 dist/ 的空壳。故先克隆你的仓库构建好，
# 放在 /opt/plugins（镜像层内持久存在，容器内后续 pnpm 重装仍可解析 file: 依赖）
RUN git clone --depth 1 https://github.com/aogg/dsh-git-idea.git /opt/plugins/dsh-git-idea \
    && cd /opt/plugins/dsh-git-idea \
    && pnpm install \
    && pnpm run build


RUN printf '%s\n' '' \
        '- id: dsh-lanmode' \
        '  config:' \
        '    mode: direct' \
        '    directHost: 0.0.0.0' \
        '    directPort: 3080' \
        '    mdns: true' \
        '    pwa: true' \
        '    mobileEnterSends: false' \
        '    tls: self-signed' \
        '    unlockPrivileged: true' \
        '    lanPinRef: ""' \
        '    tunnel: off' \
        '    tunnelTokenRef: ""' \
        '    tunnelPin: true' \
        '    allow:' \
        '      - 127.0.0.0/8' \
        '    passwordAuth: false' \
        '    authPasswordRef: ""' \
        '    publicHost: ""' \
        '    disabledUsers: []' \
        '    trustedProxyCidrs: []' \
        '    tlsSites: []' \
        '    adaptiveCompression: true' \
        >> ${DSH_HOME}_bak/profiles/web/cordis.patch.yml \
    && dsh plugin --profile web add @goodandready/dsh-lanmode@0.8.13; \
    dsh plugin --profile web add dshmarket@1.66.7; \
    dsh plugin --profile web add github:aogg/DSH-better-sidebar#main; \
    dsh plugin --profile web add github:aogg/dsh-ssh-workspace#main; \
    dsh plugin --profile web add github:aogg/dsh-resume-on-restart#master; \
    dsh plugin --profile web add github:liubaicai/dsh-codebuddy-link#main; \
    dsh plugin --profile web add /opt/plugins/dsh-git-idea; \
    dsh plugin --profile web add dsh-prompt-history@1.2.15; \
    dsh plugin --profile web add dsh-remote-auth@0.1.2 -w; \
    dsh plugin --profile web add dsh-message-copy-enhance@0.2.1; \
    dsh plugin --profile web add @changfenhuang/dsh-genui@0.14.0; \
    dsh plugin --profile web add dsh-mnemon@0.5.35; \
    dsh plugin --profile web add dsh-context@0.77.0; \
    dsh plugin --profile web add @xmanrui/dsh-im@5.6.0; \
    dsh plugin --profile web add dsh-opencode-connect; \
    cp -a ${DSH_HOME}_bak/. $DSH_HOME  \
    && rm -Rf ${DSH_HOME}_bak \
    && dsh --profile web --dump-config | grep -E "dsh-lanmode|dshmarket|dsh-git-idea|dsh-better-sidebar|dsh-prompt-history|dsh-remote-auth|dsh-message-copy-enhance|dsh-genui|dsh-mnemon|dsh-context|dsh-im|dsh-ssh-workspace|dsh-resume-on-restart|dsh-opencode-connect" \
    && mv $DSH_HOME ${DSH_HOME}_bak

# mv必须最后
