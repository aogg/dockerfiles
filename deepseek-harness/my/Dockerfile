

FROM adockero/deepseek-harness


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


# 初始化 web profile 并安装四个插件：
#   1) dsh-usage-stats                —— token 用量统计（npm）
#      https://github.com/lanlandeli/dsh-usage-stats
#   2) @linxin666/dsh-web-ui-all      —— dsh-web-ui 全家桶（npm 聚合包）
#      https://github.com/zhu1090093659/dsh-web-ui
#   4) @goodandready/dsh-lanmode      —— 局域网 HTTPS 访问（社区 Alpha）
#      烘焙 cordis.patch.yml：自签名CA + mDNS + PWA + unlockPrivileged，
#      解决局域网访问时 settings are unavailable in this browser。
#      桥接端口 3088（HTTPS），原生 3080 仅限 localhost；CA 证书：
#      https://<内网IP>:3088/dsh-lanmode/ca.crt
#   5) dsh-market                      —— 插件市场
#   6) dsh-better-sidebar@latest       —— 增强侧边栏
#   7) dsh-power-button                —— 侧边栏电源按钮/重启/关机插件
#      来源 github:keyiadiannao/dsh-power-button#master



# 局域网网段初始化脚本（entrypoint 每次启动执行 docker-entrypoint-init-sh/*.sh）：
# 启动时把当前 IP 所在 /24 网段自动追加进 cordis.patch.yml 的 dsh-lanmode allow，
# 幂等可重复执行；容器 bridge 网络下探测到的是容器内网 IP，
# 可用 docker run -e DSH_LAN_IP="192.168.1.5,10.0.0.3" 显式指定
# init 脚本必须放进模板 ${DSH_HOME}_bak：若放在 $DSH_HOME，
# VOLUME 首次挂载时目录非空，entrypoint 会误判"已初始化"而跳过模板拷贝
COPY my/my-plugin-init.sh ${DSH_HOME}_bak/docker-entrypoint-init-sh/


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
    && dsh plugin --profile web add dsh-usage-stats; \
    dsh plugin --profile web add @goodandready/dsh-lanmode; \
    dsh plugin --profile web add dsh-market; \
    dsh plugin --profile web add dsh-git-idea; \
    dsh plugin --profile web add dsh-better-sidebar@latest; \
    dsh plugin --profile web add "github:keyiadiannao/dsh-power-button#master"; \
    cp -a ${DSH_HOME}_bak/. $DSH_HOME  \
    && rm -Rf ${DSH_HOME}_bak \
    && dsh --profile web --dump-config | grep -E "@nanmicoder|dsh-lanmode|dsh-market|dsh-better-sidebar|dsh-power-button" \
    && mv $DSH_HOME ${DSH_HOME}_bak

# mv必须最后








