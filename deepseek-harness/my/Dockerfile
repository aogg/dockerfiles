

FROM adockero/deepseek-harness



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
RUN cp -a $DSH_HOME/profiles/web_bak/* $DSH_HOME/profiles/web \
    && dsh plugin --profile web add dsh-usage-stats @linxin666/dsh-web-ui-all @nanmicoder/dsh-agent-teams \
    && dsh --profile web --dump-config | grep -E "agent-teams|@nanmicoder" \
    && rm -Rf $DSH_HOME/profiles/web_bak \
    && mv $DSH_HOME/profiles/web $DSH_HOME/profiles/web_bak








