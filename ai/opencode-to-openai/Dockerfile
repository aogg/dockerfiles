# =====================================================================
# opencode-to-openai 容器镜像
# 源码仓库: https://github.com/aogg/opencode-to-openai (源码已含 opencode 1.19.5 兼容修复)
# 作用: 把 OpenCode CLI 转成 OpenAI 兼容 API 的轻量网关,
#       让 Cursor / Claude Code 等标准 OpenAI 客户端直接用 OpenCode 的免费模型
# 构建说明: GitHub Actions 构建时先把上游源码 clone 到 ai/opencode-to-openai/project/,
#           以该 project 目录作为 docker 构建上下文(context), 本文件由 -f 指定, 与上下文分离
# =====================================================================

# 基础镜像: node 22 + debian bookworm slim
# 用 slim 而非 alpine: glibc 环境对 node 原生依赖和 opencode 二进制兼容性更稳, 少踩 musl 的坑
# 若宿主机拉取 Docker Hub 慢, 可提前在构建机上配置镜像加速, 或自行换成国内源镜像站
FROM node:22-bookworm-slim

# slim 镜像裁剪掉了 git / curl, 这里补装:
#   git  -> opencode CLI 仓库相关功能依赖 git
#   curl -> 进容器调试 / 健康检查(/health)用
RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 源码在 CI 阶段已 clone 好(构建上下文即 project 目录), 直接 COPY 进镜像, 镜像内不再 clone
COPY . .

# 安装项目依赖(纯 JS 依赖, 无需本地编译)
# 注: npm 新版本用 --omit=dev, 等价于旧版的 --production; 该项目无 devDependencies, 双写法等价
RUN npm install --omit=dev --no-audit --no-fund

# 在镜像内安装 opencode CLI(网关启动时会自动检测并拉起 opencode 后端服务)
# 采用方式: npm 官方包 opencode-ai, 自带 linux x64/arm64 的 glibc 与 musl 双平台二进制,
#           安装后可执行文件落在 npm 全局 bin 目录, 即 /usr/local/bin/opencode
RUN npm install -g opencode-ai
# 备选方式(若 npm 包安装有问题, 可换官方安装脚本):
# RUN curl -fsSL https://opencode.ai/install | bash

# 入口脚本: 首次启动按 docker run -e 环境变量生成 /app/config.json(支持 PORT/API_KEY/BIND_HOST/DISABLE_TOOLS/OPENCODE_PATH/OPENCODE_SERVER_URL)
# 该文件不在上游源码里, 由 workflow 在构建前从本仓库复制进构建上下文(project 目录)
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

# 网关监听端口(与 docker-entrypoint.sh 生成的 config.json 默认 PORT 一致)
EXPOSE 8083

# 入口: entrypoint 先按 -e 生成/沿用 config.json, 再拉起下面的 CMD
ENTRYPOINT ["/app/docker-entrypoint.sh"]

# 启动入口: package.json 的 main 为 index.js, start 脚本即 node index.js
CMD ["node", "index.js"]
