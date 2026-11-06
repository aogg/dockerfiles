#!/bin/sh
# opencode-to-openai 容器入口
# 首次启动(容器内无 /app/config.json)时按 docker run -e 环境变量生成配置;
# 已有 config.json(如 -v 挂载持久化)则直接使用, 不被 -e 覆盖
# 支持: PORT API_KEY BIND_HOST DISABLE_TOOLS OPENCODE_PATH OPENCODE_SERVER_URL
set -e

CONFIG=/app/config.json

if [ ! -f "$CONFIG" ]; then
    node -e '
        const fs = require("fs");
        const env = (k, d) => { const v = process.env[k]; return (v === undefined || v === "") ? d : v; };
        const flag = (k, d) => { const v = env(k, d); return v === "true" || v === "1"; };
        const cfg = {
            PORT: parseInt(env("PORT", "8083"), 10),
            API_KEY: env("API_KEY", ""),
            BIND_HOST: env("BIND_HOST", "0.0.0.0"),
            DISABLE_TOOLS: flag("DISABLE_TOOLS", "true"),
            OPENCODE_PATH: env("OPENCODE_PATH", ""),
            OPENCODE_SERVER_URL: env("OPENCODE_SERVER_URL", "http://127.0.0.1:4097")
        };
        fs.writeFileSync("/app/config.json", JSON.stringify(cfg, null, 4));
        console.log("[entrypoint] first boot, config generated from env:", JSON.stringify(cfg));
    '
else
    echo "[entrypoint] /app/config.json exists, use it as-is (recreate container without the volume to re-apply -e)"
fi

exec "$@"
