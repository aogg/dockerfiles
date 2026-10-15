# DeepSeek Harness Docker 镜像

基于 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`@deepseek-ai/dsh`）构建的 Docker 镜像：一条命令把 dsh Web GUI（Agent Teams / 工作流 / 插件体系）跑进容器，支持通过环境变量动态配置（端口、受信 Host、自定义 OpenAI 兼容大模型等）。

镜像特点：

- 首次启动自动从镜像内置模板恢复 `$DSH_HOME`（`/root/.dsh`），之后重启/升级不覆盖已持久化的用户配置
- 支持 `DSH_LLM_*` 环境变量一键注入自定义 OpenAI 兼容大模型配置（幂等：已配置过或多次重启不会重复生成）
- 预置 `git / curl / python3 / make / g++ / procps / tree / openssh-client / rsync` 与 `pnpm`，`dsh plugin` 安装带原生构建的插件开箱可用

## adockero/deepseek-harness:latest 镜像标签

基础镜像：`node:24-slim` + 全局安装 `@deepseek-ai/dsh`，ENTRYPOINT 为 `/docker-entrypoint.sh`，默认启动 `dsh --profile web`。

### 快速开始

#### 基本使用

```bash
docker run -d --name dsh \
  -p 3080:3080 \
  adockero/deepseek-harness:latest
```

浏览器访问：`http://127.0.0.1:3080`

> dsh CLI 出于防 RCE 考虑故意拒绝 `--host 0.0.0.0`，镜像已在 profile 配置层（`cordis.patch.yml`）覆盖为监听 `0.0.0.0`；实际暴露面由 `-p` 端口映射控制。

#### 局域网 IP 访问

浏览器从局域网 IP/域名访问时，需把访问地址加入受信 Host（支持逗号分隔多个 `host:port`）：

```bash
docker run -d --name dsh \
  -p 3080:3080 \
  -e DSH_TRUSTED_HOST="192.168.1.5:3080" \
  adockero/deepseek-harness:latest
```

#### 数据持久化

配置与会话数据都在 `/root/.dsh`（镜像已声明 VOLUME）。首次启动从镜像模板恢复，之后的重启**不会**覆盖已有配置：

```bash
docker run -d --name dsh \
  -p 3080:3080 \
  -v dsh-home:/root/.dsh \
  adockero/deepseek-harness:latest
```

### 环境变量配置

#### 基础变量

| 环境变量 | 默认值 | 说明 |
|---------|-------|------|
| `DSH_PORT` | `3080` | dsh 监听端口（容器内），配合 `-p` 映射 |
| `DSH_HOME` | `/root/.dsh` | Harness 主目录（镜像已设 ENV，一般无需修改） |
| `DSH_TRUSTED_HOST` | 空 | 受信 Host 列表，逗号分隔 `host:port`，局域网访问时设置 |

#### 自定义 OpenAI 兼容大模型（DSH_LLM_*）

启动时把 `llm-pi-ai` 条目自动写入 `$DSH_HOME/profiles/web/cordis.patch.yml`（dsh 每次启动都加载的用户层配置），无需手工编辑 yml。

| 环境变量 | 必填 | 说明 |
|---------|-----|------|
| `DSH_LLM_BASE_URL` | 与 MODELS 同时设置才启用 | OpenAI 兼容服务地址（含 `/v1`） |
| `DSH_LLM_MODELS` | 同上 | 逗号分隔模型 id，如 `glm-5.3-flash,gs/glm-5.3-flash` |
| `DSH_LLM_PROVIDER_ID` | 否 | providers 映射键，默认 `custom-openai` |
| `DSH_LLM_API` | 否 | 协议类型，默认 `openai-completions` |
| `DSH_LLM_API_KEY` | 否 | API Key 明文：只保留在容器环境变量里（不写入 yml），生成的 `apiKeyEnv` 指向它 |
| `DSH_LLM_API_KEY_ENV` | 否 | 复用已有 Key 的环境变量名（`DSH_LLM_API_KEY` 未设置时生效） |
| `DSH_LLM_CONTEXT_WINDOW` | 否 | 为所有模型追加 `contextWindow`（正整数，如 `924000`） |
| `DSH_LLM_MAX_TOKENS` | 否 | 为所有模型追加 `maxTokens`（正整数，如 `101072`） |

**幂等规则（多次重启 / 已配置过不再生成）**：

- `cordis.patch.yml` 中已存在 `id: llm-pi-ai`（手动配置过或上次已生成）即跳过，绝不重复追加
- 只设置 `DSH_LLM_BASE_URL` 或只设置 `DSH_LLM_MODELS` 之一时告警跳过，不生成半截配置
- 如需按新环境变量重新生成：删除 yml 中 `# >>> dsh-env-llm` ～ `# <<< dsh-env-llm` 标记段后重启即可

**使用示例**：

```bash
docker run -d --name dsh \
  -p 3080:3080 \
  -v dsh-home:/root/.dsh \
  -e DSH_LLM_BASE_URL="http://192.168.1.10:8317/v1" \
  -e DSH_LLM_MODELS="glm-5.3-flash,gs/glm-5.3-flash" \
  -e DSH_LLM_PROVIDER_ID="my-proxy" \
  -e DSH_LLM_API_KEY="sk-xxxx" \
  -e DSH_LLM_CONTEXT_WINDOW=924000 \
  -e DSH_LLM_MAX_TOKENS=101072 \
  adockero/deepseek-harness:latest
```

**生成的配置段**（自动追加到 `cordis.patch.yml`）：

```yaml
# >>> dsh-env-llm：本段由 docker-entrypoint.sh 依据 DSH_LLM_* 环境变量自动生成
- id: llm-pi-ai
  name: "@deepseek-ai/dsh-llm-pi-ai"
  config:
    providers:
      'my-proxy':
        apiKeyEnv: DSH_LLM_API_KEY
        api: openai-completions
        baseURL: 'http://192.168.1.10:8317/v1'
        # 智谱 GLM 不接受 developer 角色（400 code 1214 角色信息不正确）；
        # 自建代理 URL 无法被 pi-ai 识别为 zai，必须显式关闭 developer 角色
        compat:
          supportsDeveloperRole: false
        models:
          - id: 'glm-5.3-flash'
            name: 'glm-5.3-flash'
            contextWindow: 924000
            maxTokens: 101072
            reasoningEfforts:
              off: null
              low: low
              medium: medium
              high: high
              max: max
# <<< dsh-env-llm
```

`compat.supportsDeveloperRole: false` 为固定生成：智谱 GLM 不接受 developer 角色（400 code 1214），自建代理 URL 也无法被 pi-ai 识别为 zai，必须显式关闭。

#### 自定义初始化脚本

entrypoint 每次启动按文件名顺序执行 `$DSH_HOME/docker-entrypoint-init-sh/*.sh`（目录不存在时跳过；任一脚本失败即终止启动），可在持久化卷里放自己的初始化逻辑：

```bash
docker exec dsh bash -c 'mkdir -p $DSH_HOME/docker-entrypoint-init-sh \
  && echo "echo hi" > $DSH_HOME/docker-entrypoint-init-sh/00-hello.sh'
docker restart dsh
```

### Docker Compose 示例

```yaml
services:
  dsh:
    image: adockero/deepseek-harness:latest
    container_name: dsh
    ports:
      - "3080:3080"
    environment:
      - DSH_TRUSTED_HOST=192.168.1.5:3080
      - DSH_LLM_BASE_URL=http://192.168.1.10:8317/v1
      - DSH_LLM_MODELS=glm-5.3-flash,gs/glm-5.3-flash
      - DSH_LLM_API_KEY=${DSH_LLM_API_KEY}
    volumes:
      - dsh-home:/root/.dsh
    restart: unless-stopped

volumes:
  dsh-home:
```

## adockero/deepseek-harness:my 镜像标签

基于 `latest` 预装常用插件的增强版，并烘焙局域网访问配置（dsh-lanmode 自签名 HTTPS + PWA）。

### 预装插件

| 插件 | 说明 |
|------|------|
| `dsh-lanmode` | 局域网直接访问（自签名 TLS、mDNS、PWA），解决局域网打开时 `settings are unavailable in this browser` |
| `dsh-remote-auth` | `/mobile-auth` 远程授权页（会话链接/二维码铸造），运行期按 env 重建门禁 |
| `dsh-power-button` | 侧边栏电源按钮 / 重启 / 关机 |
| `dsh-prompt-history` | 类 shell 输入历史（↑/↓ 召回）+ 终端式复制粘贴 |
| `dsh-better-sidebar` | 增强侧边栏 |
| `dsh-usage-stats` | token 用量统计 |
| `dsh-market` | 插件市场 |
| `dsh-git-idea` | Git 增强 |

### 快速开始

```bash
docker run -d --name dsh \
  -p 3080:3080 -p 3088:3088 \
  -v dsh-home:/root/.dsh \
  -e DSH_LAN_IP="192.168.1.5" \
  -e DSH_REMOTE_AUTH_PIN="abcd1234" \
  adockero/deepseek-harness:my
```

- `3080`：dsh 原生端口；`3088`：dsh-lanmode 的 HTTPS/PWA 桥接端口
- 局域网设备首次访问需信任自签名 CA：`https://<内网IP>:3088/dsh-lanmode/ca.crt`

### 环境变量配置

在 `latest` 全部变量基础上，增加（由启动期 init 脚本 `my-plugin-init.sh` 幂等消费）：

| 环境变量 | 默认值 | 说明 |
|---------|-------|------|
| `DSH_LAN_IP` | 自动探测 | 逗号分隔多个 IP，把所在 /24 网段注入 dsh-lanmode `allow`；bridge 网络下自动探测到的是容器内网 IP，建议显式指定宿主机局域网 IP |
| `DSH_REMOTE_AUTH_AUTHORITIES` | 空 | 逗号分隔 Host 白名单（裸主机名或 `host:port`），写入 `/mobile-auth` 的 `allowedAuthorities`；不设 = 仅回环放行 |
| `DSH_REMOTE_AUTH_PIN` | 空 | 8 位字母数字 PIN；不设 = 关闭 PIN 门禁 |

说明：

- 启动期会自动探测容器 IP 并把所在 /24 网段同时加进 dsh-lanmode `allow` 与 dsh-remote-auth `allowedSubnets`（已存在/被更大网段覆盖时跳过，不随重启累积）
- `dsh-remote-auth` 门禁块每次启动按当前 env 重建，**手动改该块会被覆盖**，请一律用 env 配置
- 变更 env 后 `docker restart` 即生效

## adockero/deepseek-harness:my-more 镜像标签

基于 `:my`，额外全局安装第三方 Agent CLI：`@tencent-ai/codebuddy-code`、`freebuff`、`command-code`、`@qoder-ai/qoder-agent-sdk`，供 dsh 子代理/终端直接调用。用法同 `:my`。

## 相关链接

- [DeepSeek Harness GitHub](https://github.com/deepseek-ai/deepseek-harness)
- [hub.docker.com](https://hub.docker.com/u/adockero)
- [构建工作流](/.github/workflows/deepseek-harness.yml)
