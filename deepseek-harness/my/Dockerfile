

FROM adockero/deepseek-harness


RUN npm install -g @tencent-ai/codebuddy-code freebuff command-code @qoder-ai/qoder-agent-sdk

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


# 初始化 web profile 并安装四个插件：
#   1) dsh-usage-stats                —— token 用量统计（npm）
#      https://github.com/lanlandeli/dsh-usage-stats
#   2) @linxin666/dsh-web-ui-all      —— dsh-web-ui 全家桶（npm 聚合包）
#      https://github.com/zhu1090093659/dsh-web-ui
#   3) @nanmicoder/dsh-agent-teams    —— 多模型 agent 小队（npm）
#      https://github.com/NanmiCoder/dsh-agent-teams
#   4) @goodandready/dsh-lanmode      —— 局域网 HTTPS 访问（社区 Alpha）
#      烘焙 cordis.patch.yml：自签名CA + mDNS + PWA + unlockPrivileged，
#      解决局域网访问时 settings are unavailable in this browser。
#      桥接端口 3088（HTTPS），原生 3080 仅限 localhost；CA 证书：
#      https://<内网IP>:3088/dsh-lanmode/ca.crt
RUN cp -a $DSH_HOME/profiles/web_bak/* $DSH_HOME/profiles/web \
    && printf '%s\n' \
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
        > $DSH_HOME/profiles/web/cordis.patch.yml \
    && dsh plugin --profile web add dsh-usage-stats @nanmicoder/dsh-agent-teams @goodandready/dsh-lanmode \
    && dsh --profile web --dump-config | grep -E "agent-teams|@nanmicoder|dsh-lanmode" \
    && rm -Rf $DSH_HOME/profiles/web_bak \
    && mv $DSH_HOME/profiles/web $DSH_HOME/profiles/web_bak


# 局域网网段初始化脚本（entrypoint 每次启动执行 docker-entrypoint-init-sh/*.sh）：
# 启动时把当前 IP 所在 /24 网段自动追加进 cordis.patch.yml 的 dsh-lanmode allow，
# 幂等可重复执行；容器 bridge 网络下探测到的是容器内网 IP，
# 可用 docker run -e DSH_LAN_IP="192.168.1.5,10.0.0.3" 显式指定
COPY my/my-plugin-init.sh $DSH_HOME/docker-entrypoint-init-sh/









