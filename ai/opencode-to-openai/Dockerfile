# =====================================================================
# opencode-to-openai 容器镜像
# 上游项目: https://github.com/dxxzst/opencode-to-openai (上游无自带 Dockerfile)
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

# 运行时补丁: 修复上游 DISABLE_TOOLS=true 时禁用 opencode 全部工具导致请求挂起的问题
# 背景: 实测 opencode 1.19.5 + zen 免费模型(如 opencode/deepseek-v4.1-flash-free)下,
#       tools 里只要禁用 read 或 glob 任意一个, prompt 请求就永久挂起无响应; 禁用其余工具(bash/edit/write/task/webfetch 等)均正常
# 做法: 字符串替换改上游 src/proxy.js 的 getToolOverrides, read/glob 这两个只读工具保持启用, 其余 12 个工具仍禁用
#       安全兜底: read/glob 只读、无写入/执行能力, 且上游还有 stripFunctionCalls 过滤 + TOOL_GUARD_MESSAGE 系统提示作第二道防线
# 保护: 目标代码找不到时 process.exit(1) 让构建失败, 防止上游改名后补丁静默失效; 上游修复该问题后可移除本步骤
RUN node -e "const fs=require('fs'); \
        const file='src/proxy.js'; \
        const src=fs.readFileSync(file,'utf8'); \
        const target='ids.forEach((id) => {' + '\n' \
            + '                overrides[id] = false;' + '\n' \
            + '            });'; \
        const replacement='ids.forEach((id) => {' + '\n' \
            + '                /* 镜像内补丁: opencode>=1.19 + zen 免费模型下, tools 里禁用 read/glob 任一会导致 prompt 请求永久挂起 */' + '\n' \
            + '                /* 这两个只读工具保持启用, 其余工具仍禁用; 上游 stripFunctionCalls 过滤 + TOOL_GUARD_MESSAGE 系统提示作为第二道防线 */' + '\n' \
            + '                overrides[id] = [\"read\",\"glob\"].includes(String(id).toLowerCase()) ? true : false;' + '\n' \
            + '            });'; \
        if (!src.includes(target)) { \
            console.error('[patch] 未在 ' + file + ' 找到目标代码, 上游可能已改动 getToolOverrides, 请人工核对补丁'); \
            process.exit(1); \
        } \
        fs.writeFileSync(file, src.replace(target, replacement)); \
        console.log('[patch] ' + file + ' 已打补丁: read/glob 保持启用, 其余工具禁用');"

# 运行时补丁(流式 SSE 兼容): 修复 opencode>=1.19 事件流无 delta 字段导致流式输出零内容的问题
# 背景: 实测镜像内 opencode 1.19.5 的 SSE message.part.updated 事件实际结构为
#       {type:'message.part.updated', properties:{sessionID, part:{type:'text', text:'<该 part 当前全量文本>', ...}, time}}
#       即没有 properties.delta 字段; 上游 collectFromEvents 按 const { part, delta } = event.properties 取增量,
#       delta 永远 undefined -> 流式响应零内容, 只剩 finish 块
#       另: assistant 很快 finish 时, message.updated(finish=stop) 会先于 4s firstDeltaTimer 到达,
#       事件收集带着空 content 提前 resolve, 上游已有的 noData/idleTimeout 兜底轮询都覆盖不到这条路径
#       非流式路径(prompt+轮询)不受影响, 无需改动
# 做法: 补丁A(事件结构兼容) 放宽 sessionID 匹配并自行差量化出 delta, 保留原有 if(delta){...} 结构不动;
#       补丁B(空响应兜底) 流式没发过任何内容时, 兜底轮询一次取完整回复再下发, 无内容则不发任何 delta
# 保护: 两处目标代码各自校验存在性, 找不到时 process.exit(1) 让构建失败; 上游修复后可移除本步骤
RUN node -e "const fs=require('fs'); \
        const file='src/proxy.js'; \
        const src=fs.readFileSync(file,'utf8'); \
        const targetA='                        if (event.type === \'message.part.updated\' && event.properties.part.sessionID === sessionId) {' + '\n' \
            + '                            const { part, delta } = event.properties;'; \
        const replacementA='                        /* 镜像内补丁A: opencode>=1.19 的 SSE message.part.updated 事件没有 properties.delta 字段, */' + '\n' \
            + '                        /* part.text 是该 part 当前全量文本, 需按已累积内容差量化出增量; */' + '\n' \
            + '                        /* 并兼容部分版本 part 上无 sessionID 时回落到 properties.sessionID 匹配 */' + '\n' \
            + '                        if (event.type === \'message.part.updated\' && (event.properties.part.sessionID || event.properties.sessionID) === sessionId) {' + '\n' \
            + '                            const { part } = event.properties;' + '\n' \
            + '                            /* 镜像内补丁A: 老版本事件自带 properties.delta 则优先用(防御性兼容); 缺失时按已累积内容差量化 */' + '\n' \
            + '                            let delta = event.properties.delta;' + '\n' \
            + '                            if (!delta && (part.type === \'text\' || part.type === \'reasoning\') && typeof part.text === \'string\') {' + '\n' \
            + '                                const acc = part.type === \'reasoning\' ? reasoning : content;' + '\n' \
            + '                                delta = typeof part.text === \'string\' ? (part.text.startsWith(acc) ? part.text.slice(acc.length) : part.text) : undefined;' + '\n' \
            + '                            }'; \
        const targetB='                        if (collected && !streamedContent && !streamedReasoning && (collected.reasoning || collected.content)) {' + '\n' \
            + '                            if (collected.reasoning) sendDelta(collected.reasoning, true);' + '\n' \
            + '                            if (collected.content) sendDelta(collected.content, false);' + '\n' \
            + '                        }'; \
        const replacementB='                        /* 镜像内补丁B: opencode>=1.19 SSE delta 缺失时的兜底轮询: assistant 很快 finish 时 */' + '\n' \
            + '                        /* message.updated(finish=stop) 先于 4s firstDeltaTimer 到达, 事件收集带着空内容提前 resolve, */' + '\n' \
            + '                        /* 上游 noData/idleTimeout 兜底轮询都覆盖不到; 此处只要流式没发过任何内容, */' + '\n' \
            + '                        /* 就轮询一次取完整回复再下发(stripFunctionCalls 用法与上方流式分支一致, 过滤不 trim); */' + '\n' \
            + '                        /* 轮询也无内容则不发任何 delta, 响应仍只有 stop 块 */' + '\n' \
            + '                        if (collected && !streamedContent && !streamedReasoning) {' + '\n' \
            + '                            const { content: polledContent, reasoning: polledReasoning } = await pollForAssistantResponse(sessionId, REQUEST_TIMEOUT_MS);' + '\n' \
            + '                            const safePolledReasoning = stripFunctionCalls(polledReasoning, false);' + '\n' \
            + '                            const safePolledContent = stripFunctionCalls(polledContent, false);' + '\n' \
            + '                            if (safePolledReasoning) sendDelta(safePolledReasoning, true);' + '\n' \
            + '                            if (safePolledContent) sendDelta(safePolledContent, false);' + '\n' \
            + '                        }'; \
        if (!src.includes(targetA)) { \
            console.error('[patch] 未在 ' + file + ' 找到补丁A目标代码(message.part.updated 增量处理), 上游可能已改动, 请人工核对补丁'); \
            process.exit(1); \
        } \
        if (!src.includes(targetB)) { \
            console.error('[patch] 未在 ' + file + ' 找到补丁B目标代码(空流式内容兜底), 上游可能已改动, 请人工核对补丁'); \
            process.exit(1); \
        } \
        fs.writeFileSync(file, src.replace(targetA, replacementA).replace(targetB, replacementB)); \
        console.log('[patch] ' + file + ' 已打补丁A+B: SSE 无 delta 时差量化 + 空内容兜底轮询, 修复流式输出');"

# 生成运行配置: 以上游 config.json.example 为底, 覆盖为容器场景默认值
# 注意: JSON 不支持注释, 各字段说明写在这里和 README.md, 用 node 改 JSON 可不受上游示例格式变化影响
# 程序读取优先级: 环境变量 > config.json > 程序内置默认, 所以这里只是出厂默认, 运行时可用 -e 覆盖
RUN cp config.json.example config.json \
    && node -e "const fs=require('fs'); \
        const c=JSON.parse(fs.readFileSync('config.json','utf8')); \
        c.PORT=8083; \
        /* 网关监听端口 */ \
        c.BIND_HOST='0.0.0.0'; \
        /* 容器内必须监听 0.0.0.0, 上游默认 127.0.0.1 会导致宿主机端口映射不通 */ \
        c.API_KEY=''; \
        /* 网关鉴权 key, 留空=不鉴权; 生产环境建议 docker run -e API_KEY=xxx 覆盖 */ \
        c.DISABLE_TOOLS=true; \
        /* 禁用 opencode 工具调用, 避免模型在容器内执行命令/改文件 */ \
        c.OPENCODE_PATH=''; \
        /* 留空: 回落到程序默认值 opencode 按 PATH 查找(npm 全局装在 /usr/local/bin/opencode), \
           程序还会自动探测 ~/.opencode/bin、npm/pnpm 全局目录; \
           若自动探测失败, 改成绝对路径, 如 /usr/local/bin/opencode */ \
        fs.writeFileSync('config.json', JSON.stringify(c, null, 4));"

# 网关监听端口(与上面 config.json 的 PORT 保持一致)
EXPOSE 8083

# 启动入口: package.json 的 main 为 index.js, start 脚本即 node index.js
CMD ["node", "index.js"]
