# Camoufox 浏览器镜像：noVNC 可视 + 默认开启 Camoufox 官方远程连接（Playwright WebSocket 服务器）
# 基于 ubuntu:24.04；Camoufox 是 Firefox 反检测分支
# 端口：6080 noVNC 网页 | 5900 VNC | 9333 Playwright WS（camoufox.server.launch_server）
FROM ubuntu:24.04

# 可选固定 Camoufox 浏览器版本（如 official/135.0-beta.25），留空则安装当前 python 包配对版本
ARG CAMOUFOX_VERSION=""
ARG DEBIAN_FRONTEND=noninteractive

# python 虚拟环境（ubuntu 24.04 pip 受 PEP668 管控，统一用 venv）
ENV VIRTUAL_ENV=/opt/camoufox-venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

# 运行时默认值（都可用 docker run -e 覆盖，详见 README.md）
ENV DATA_DIR=/data \
    DISPLAY=:99 \
    SCREEN_SIZE=1366x768 \
    VNC_PASSWORD="" \
    GEOIP=false \
    LOCALE=en-US \
    FINGERPRINT_OS="" \
    WS_PATH="/" \
    EXTRA_FIREFOX_ARGS="" \
    DEBUG=false

# 1. 系统依赖：
#    - 显像链路 xvfb(X服务) + x11vnc(VNC服务) + novnc/websockify(网页端)
#    - 浏览器运行库（ubuntu 24.04 上 libasound2/libatk-bridge2.0-0/libgtk-3-0 已更名为 *t64）
#    - 中文字体 fonts-noto-cjk，西文 fonts-liberation，彩色 emoji fonts-noto-color-emoji
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        tzdata \
        python3 \
        python3-venv \
        xvfb \
        x11vnc \
        novnc \
        websockify \
        libasound2t64 \
        libatk-bridge2.0-0t64 \
        libgtk-3-0t64 \
        libdbus-glib-1-2 \
        libgbm1 \
        libnss3 \
        libx11-xcb1 \
        libxss1 \
        libxt6 \
        libxtst6 \
        fonts-noto-cjk \
        fonts-liberation \
        fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/* \
    # noVNC 默认页指向 vnc.html，使 http://ip:6080/ 可直接打开
    && ln -sf vnc.html /usr/share/novnc/index.html

# 2. 安装 camoufox python 包（[geoip] 提供 GEOIP=true 时的 IP 地理库能力；
#    camoufox 自带 playwright(<1.63) 依赖，远程连接用的 launch_server 在 camoufox.server 模块）
RUN python3 -m venv "${VIRTUAL_ENV}" \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir "camoufox[geoip]"

# 3. 构建期下载浏览器二进制（自动按 CPU 架构选择 linux x86_64/arm64 资产）。
#    CAMOUFOX_ASSET_MIRROR：可选镜像加速前缀（如 https://ghfast.top）。浏览器 zip 约 1.2GB，
#    境内直连 github.com 只有 ~50KB/s，走镜像可到 ~1.6MB/s；下载后仍按 GitHub 发布的
#    sha256 严格校验，内容完整性不受镜像影响。GitHub Actions 上无需设置（直连快）。
#    注意：指定版本安装的是 beta 预发布构建，fetch 在非交互环境下会弹确认，
#    用 `yes |` 自动应答；默认（不带版本）走配对 pinned 版本，无确认直接装。
ARG CAMOUFOX_ASSET_MIRROR=""
COPY fetch_camoufox.py /usr/local/bin/fetch_camoufox.py
RUN if [ -n "${CAMOUFOX_VERSION}" ]; then \
        yes | python /usr/local/bin/fetch_camoufox.py "${CAMOUFOX_VERSION}"; \
    else \
        yes | python /usr/local/bin/fetch_camoufox.py; \
    fi

# 4. 入口脚本与启动器
COPY start.sh launch_browser.py /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh /usr/local/bin/launch_browser.py \
    && mkdir -p /data

WORKDIR /data

EXPOSE 5900 6080 9333

ENTRYPOINT ["/usr/local/bin/start.sh"]
