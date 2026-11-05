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

镜像内置 `config.json` 出厂默认值如下,程序读取优先级为 **环境变量 > config.json > 程序内置默认**,运行时用 `-e` 即可覆盖:

| 环境变量 | 内置默认值 | 说明 |
|---------|-----------|------|
| `PORT` | `8083` | 网关监听端口 |
| `API_KEY` | 空(不鉴权) | 网关鉴权 key,生产环境建议必填 |
| `BIND_HOST` | `0.0.0.0` | 容器内必须监听 0.0.0.0,端口映射才能通(上游默认 127.0.0.1 已在镜像内改掉) |
| `OPENCODE_DISABLE_TOOLS` | `true` | 禁用 opencode 工具调用,避免模型在容器内执行命令/改文件 |
| `OPENCODE_PATH` | 空(自动探测) | opencode 可执行文件路径;留空时按 PATH 查找(npm 全局安装在 `/usr/local/bin/opencode`),程序还会自动探测 `~/.opencode/bin`、npm/pnpm 全局目录 |
| `OPENCODE_SERVER_URL` | `http://127.0.0.1:4097` | 网关内部自动拉起的 opencode 后端服务地址,一般不用改 |

修改示例(换端口 + 开启鉴权):

```bash
docker run -d \
  --restart=always \
  --network common-all \
  --name opencode-to-openai \
  --privileged \
  -p 9090:9090 \
  -e PORT=9090 \
  -e API_KEY=my-secret-key \
  adockero/opencode-to-openai
```

## 相关链接

- [opencode-to-openai GitHub](https://github.com/dxxzst/opencode-to-openai)
- [OpenCode 官网](https://opencode.ai)
