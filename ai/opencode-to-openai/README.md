# opencode-to-openai Docker 镜像

基于 [dxxzst/opencode-to-openai](https://github.com/dxxzst/opencode-to-openai) 构建的 Docker 镜像。

`opencode-to-openai` 是一个轻量级网关,把 [OpenCode](https://opencode.ai) CLI 转成标准的 OpenAI 兼容 REST API。通过它,可以在 Cursor、Claude Code 等任何支持 OpenAI 格式的 AI 客户端里,直接调用 OpenCode 提供的免费模型(如 Kimi k2.5、GLM 4.7、MiniMax m2.1)。

镜像内已自带 Node.js 22、上游项目源码和 OpenCode CLI(npm 包 `opencode-ai`),开箱即用;无需宿主机安装任何东西。

## adockero/opencode-to-openai:latest 镜像标签

- `adockero/opencode-to-openai:latest` - OpenCode 转 OpenAI 兼容 API 网关

### 快速开始

#### 基本使用

```bash
docker run -d \
  --restart=always \
  --network common-all \
  --name opencode-to-openai \
  --privileged \
  -p 8083:8083 \
  adockero/opencode-to-openai
```

服务地址:`http://your-ip:8083`

#### opencode 认证(重要)

容器内的 OpenCode CLI 需要先认证才能调用模型,二选一:

方式 1:进容器登录一次(按提示选择模型提供商并完成授权):

```bash
docker exec -it opencode-to-openai opencode auth login
```

方式 2:直接挂载宿主机已登录过的 opencode 凭据目录(`~` 为宿主机当前用户的 home,容器内以 root 运行):

```bash
docker run -d \
  --restart=always \
  --network common-all \
  --name opencode-to-openai \
  --privileged \
  -p 8083:8083 \
  -v ~/.local/share/opencode:/root/.local/share/opencode \
  adockero/opencode-to-openai
```

### 接口自检

健康检查:

```bash
curl http://127.0.0.1:8083/health
```

模型列表(配置了 `API_KEY` 时加 `-H "Authorization: Bearer <YOUR_API_KEY>"`):

```bash
curl http://127.0.0.1:8083/v1/models
```

对话补全(非流式示例):

```bash
curl -X POST http://127.0.0.1:8083/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"opencode/kimi-k2.5-free","messages":[{"role":"user","content":"hi"}],"stream":false}'
```

### 配置说明

配置不再构建期固化:容器**首次启动**(容器内无 `/app/config.json`)时,由入口脚本 `docker-entrypoint.sh` 按 `docker run -e` 环境变量生成 `/app/config.json`;之后每次启动直接沿用已有的 config.json。支持的变量与默认值如下:

| 环境变量 | 默认值 | 说明 |
|---------|-----------|------|
| `PORT` | `8083` | 网关监听端口 |
| `API_KEY` | 空(不鉴权) | 网关鉴权 key,生产环境建议必填 |
| `BIND_HOST` | `0.0.0.0` | 容器内必须监听 0.0.0.0,端口映射才能通(上游默认 127.0.0.1,入口脚本已改为 0.0.0.0) |
| `DISABLE_TOOLS` | `true` | 禁用 opencode 工具调用,避免模型在容器内执行命令/改文件 |
| `OPENCODE_PATH` | 空(自动探测) | opencode 可执行文件路径;留空时按 PATH 查找(npm 全局安装在 `/usr/local/bin/opencode`),程序还会自动探测 `~/.opencode/bin`、npm/pnpm 全局目录 |
| `OPENCODE_SERVER_URL` | `http://127.0.0.1:4097` | 网关内部自动拉起的 opencode 后端服务地址,一般不用改 |

示例(开启鉴权):

```sh
docker run -d --restart=always --network common-all --name opencode-to-openai --privileged -p 8083:8083 \
  -e PORT=8083 -e API_KEY=your-key -e DISABLE_TOOLS=true \
  adockero/opencode-to-openai
```

配置生效规则:

- `-e` 只在**首次启动**生成 config.json 时读取;`/app/config.json` 已存在时直接使用、**不被 `-e` 覆盖**(如 `-v` 挂载持久化的配置,优先于 `-e`)
- 想用新的 `-e` 重新生成:删掉挂载的 config.json 文件(或去掉 `-v` 挂载)后重建容器即可
- 程序运行时读取优先级为 **config.json > 带 `OPENCODE_` 前缀的程序内置环境变量(如 `OPENCODE_DISABLE_TOOLS`) > 程序内置默认**,所以上面 `-e` 生成的 config.json 是最终生效配置

### 已知问题与兼容修复

以下两个 opencode 1.19.5 兼容问题,已直接修复在源码仓库 [aogg/opencode-to-openai](https://github.com/aogg/opencode-to-openai)(`dxxzst/opencode-to-openai` 的 fork)的 `src/proxy.js` 中——不再是镜像内补丁,镜像直接从该仓库构建,Dockerfile 内无任何运行时打补丁步骤:

- **修复一(工具挂起)**:opencode>=1.19 + zen 免费模型(如 `opencode/deepseek-v4.1-flash-free`)下,`DISABLE_TOOLS=true`(镜像内置默认)会把 opencode 全部工具禁用,而 tools 里只要禁用 `read` 或 `glob` 任意一个,prompt 请求就会永久挂起无响应,表现为网关不返回对话内容。修复做法:`read`、`glob` 两个只读工具保持启用,其余工具(bash/edit/write/task/webfetch/question/grep/skill 等)仍全部禁用;`read`/`glob` 只读、无写入/执行能力,且源码里还有 `stripFunctionCalls` 输出过滤 + `TOOL_GUARD_MESSAGE` 系统提示作为第二道防线。
- **修复二(流式 SSE 兼容)**:opencode>=1.19 的 SSE `message.part.updated` 事件没有 `properties.delta` 字段,`part.text` 是该 part 当前**全量文本**,修复前按 `const { part, delta } = event.properties` 取增量永远是 undefined,导致流式响应零内容、只剩 finish 块;且 assistant 很快结束时 `message.updated(finish=stop)` 会先于 4s 首包定时器到达,事件收集带着空内容提前 resolve,原有 noData/idleTimeout 兜底轮询都覆盖不到这条路径(非流式路径不受影响)。修复做法:事件自带 `properties.delta` 时优先用(兼容老版本),缺失时按已累积内容对 `part.text` 差量化出增量(`startsWith` 判断后 `slice`);流式一个字都没发过时,兜底轮询一次 `pollForAssistantResponse` 取完整回复再下发(经 `stripFunctionCalls` 同款过滤),轮询也无内容则不发任何 delta。

## 相关链接

- [opencode-to-openai GitHub](https://github.com/dxxzst/opencode-to-openai)
- [OpenCode 官网](https://opencode.ai)
