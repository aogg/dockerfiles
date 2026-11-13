# Camoufox Docker 镜像（noVNC 可视 + 默认开启官方远程连接）

基于 [Camoufox](https://github.com/daijro/camoufox)（Firefox 反检测分支）构建的 Docker 镜像：

- **noVNC 网页可视化**：浏览器以有窗口模式跑在容器内 Xvfb 虚拟桌面上，通过网页直接看到/操作真实浏览器窗口
- **默认开启 Camoufox 官方远程连接**：容器内由 `camoufox.server.launch_server` 启动 Playwright WebSocket 服务器（9333 端口），任意语言的 Playwright 客户端 `firefox.connect("ws://ip:9333")` 直连；**不使用 CDP**
- **指纹持久化**：首次启动用 camoufox 内置 fpgen 生成浏览器指纹保存在 `/data/fingerprint.json`，重启复用，身份稳定
- 显像链路：Xvfb(:99) → x11vnc(:5900) → websockify/noVNC(:6080)，浏览器窗口通过 noVNC 实时可见

## adockero/camoufox:novnc 镜像标签

- `adockero/camoufox:novnc` - noVNC 可视化 + 默认开启 Playwright WS 远程连接(9333)，支持 amd64/arm64

### 快速开始

```bash
docker run -d --name camoufox \
  --restart=always \
  --network common-all \
  --shm-size=2g \
  -p 6080:6080 \
  -p 5900:5900 \
  -p 9333:9333 \
  -v camoufox-data:/data \
  adockero/camoufox:novnc
```

- noVNC 可视页面：`http://ip:6080/vnc.html?autoconnect=true`（`http://ip:6080/` 也可以）
- Playwright WS 端点：`ws://ip:9333`（`WS_PATH` 默认 `/` = 根路径）

### 环境变量配置（docker run -e）

| 环境变量 | 默认值 | 说明 |
|---------|-------|------|
| `SCREEN_SIZE` | `1366x768` | Xvfb 虚拟桌面分辨率，同时也是浏览器窗口大小，格式 `宽x高` |
| `VNC_PASSWORD` | 空 | x11vnc 访问密码，**空 = 免密**（仅建议内网使用），设置后 noVNC/VNC 连接需输密码 |
| `GEOIP` | `false` | `true` 时按容器出口 IP 伪造经纬度/时区/语言（首次启用需外网下载 IP 地理库） |
| `LOCALE` | `en-US` | 浏览器语言（Intl、界面语言），如 `zh-CN` |
| `FINGERPRINT_OS` | 空 | 指纹的操作系统：空 = `windows\|macos\|linux` 随机；可指定单个如 `windows`，或 `windows\|macos` 随机二选一 |
| `WS_PATH` | `/` | Playwright WS 服务路径；默认 `/` = 根路径，客户端直接连 `ws://ip:9333`；设为如 `camoufox` 则连 `ws://ip:9333/camoufox`（留空按 `/` 处理） |
| `EXTRA_FIREFOX_ARGS` | 空 | 追加的 Firefox 启动参数，空格分隔 |
| `TZ` / `TIMEZONE` | 空 | 容器时区，如 `Asia/Shanghai` |
| `DEBUG` | `false` | `true` 时打印发送给浏览器的完整指纹配置（调试用） |
| `DATA_DIR` | `/data` | 数据目录，一般不需要改 |

### 卷（docker run -v）

| 卷 | 说明 |
|----|------|
| `/data` | **建议持久化**。包含：`fingerprint.json`（持久化指纹，删除后会重新生成新身份）、`camoufox-info.json`（最近一次启动的状态信息）。注意：远程服务器模式（launch_server）每次启动使用临时 profile，浏览器登录态不落盘，持久化的是"指纹身份" |

### 端口（docker run -p）

| 端口 | 说明 |
|------|------|
| `6080` | noVNC 网页（websockify + noVNC，浏览器直接打开 `http://ip:6080/vnc.html?autoconnect=true`） |
| `5900` | 原生 VNC（x11vnc，可用任意 VNC 客户端连接） |
| `9333` | Playwright WS 远程连接（Camoufox 官方 Remote Server，见下文连接示例） |

### Playwright 远程连接示例

Python（同步 API）：

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.firefox.connect("ws://ip:9333")
    page = browser.new_page()
    page.goto("https://httpbin.org/user-agent")
    print(page.content())
    browser.close()
```

Node.js：

```javascript
const { firefox } = require('playwright');

(async () => {
  const browser = await firefox.connect('ws://ip:9333');
  const page = await browser.newPage();
  await page.goto('https://httpbin.org/user-agent');
  console.log(await page.content());
  await browser.close();
})();
```

- 若设置了 `-e WS_PATH=camoufox`，连接地址改为 `ws://ip:9333/camoufox`
- 因为远程服务器整个生命周期只用**一个浏览器实例**，多个客户端连进来共享同一个浏览器进程；指纹不会在会话间轮换，需要换身份时重启容器（配合 `FINGERPRINT_OS` 等参数）或删除 `/data/fingerprint.json`

### 指纹稳定性

- 首次启动用 camoufox 内置 fpgen 按当前 `SCREEN_SIZE`/`FINGERPRINT_OS` 生成指纹，写入 `/data/fingerprint.json`
- 之后每次启动读取并复用该指纹，只要 `/data` 卷还在，**身份（UA/屏幕/WebGL/字体等）保持稳定**
- 删除 `/data/fingerprint.json` 后重启 = 重新生成新身份

### 固定 Camoufox 浏览器版本（构建参数）

构建时通过 `CAMOUFOX_VERSION` 指定，如 `official/135.0-beta.25`；留空则安装与
camoufox python 包配对的 pinned 版本：

```bash
docker build --build-arg CAMOUFOX_VERSION=official/135.0-beta.25 -t adockero/camoufox:novnc ./camoufox/
```

### 境内构建加速（构建参数）

浏览器二进制 zip 约 1.2GB，构建期从 github.com 下载。境内网络直连只有 ~50KB/s（约 7 小时），
推荐加镜像加速前缀；下载完成后仍按 GitHub 发布的 sha256 严格校验，内容完整性不受镜像影响：

```bash
docker build \
  --build-arg CAMOUFOX_ASSET_MIRROR=https://ghfast.top \
  -t adockero/camoufox:novnc ./camoufox/
```

- `CAMOUFOX_ASSET_MIRROR`：GitHub 下载加速前缀（镜像只改写传输路径，如 `https://ghfast.top`），
  留空则直连 github.com（GitHub Actions 等境外构建环境无需设置）
- 镜像时效性自行验证，已知候选见 `camoufox/fetch_camoufox.py` 文件头注释
- apt/pip 慢时还可叠加 docker 内置代理参数：`--build-arg http_proxy=... --build-arg https_proxy=...`

### 查看运行状态

```bash
docker logs camoufox          # 启动日志会打印 "Websocket endpoint: ws://..." 与 noVNC/VNC 地址
cat /data/camoufox-info.json  # 最近一次启动的状态（ws 地址、端口、指纹 UA、分辨率等）
```

### Docker Compose 示例

```yaml
services:
  camoufox:
    image: adockero/camoufox:novnc
    container_name: camoufox
    shm_size: "2g"
    restart: unless-stopped
    environment:
      - SCREEN_SIZE=1366x768
      - LOCALE=zh-CN
      - TZ=Asia/Shanghai
    ports:
      - "6080:6080"
      - "5900:5900"
      - "9333:9333"
    volumes:
      - camoufox-data:/data

volumes:
  camoufox-data:
```

## 相关链接

- [Camoufox GitHub](https://github.com/daijro/camoufox)
- [Camoufox Remote Server 文档](https://camoufox.com/python/remote-server/)
- [Camoufox 反检测属性文档](https://github.com/daijro/camoufox/blob/main/README.md)
