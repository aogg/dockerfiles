FROM adockero/hermes


# 安装 hermes-hudui 所需系统依赖
# 基础镜像已有 hermes CLI、hermes 用户、/opt/data 数据目录
# hudui 需要 Python 3.11+ 和 Node.js 22.12+ 来构建前端
RUN apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -y \
        software-properties-common \
        python3.11 \
        python3.11-venv \
        python3-pip \
        curl \
    && rm -rf /var/lib/apt/lists/*


# 安装 Node.js 22.x（hudui 前端构建需要 22.12+）
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt install -y nodejs \
    && rm -rf /var/lib/apt/lists/*


# 克隆并安装 hermes-hudui
# 安装到 /opt/hermes-hudui，构建时以 root 操作，运行时 hermes 用户需要有读取权限
RUN git clone https://github.com/joeynyc/hermes-hudui.git /opt/hermes-hudui \
    && cd /opt/hermes-hudui \
    && python3.11 -m venv venv \
    && source venv/bin/activate \
    && pip install --upgrade pip \
    && pip install -e . \
    && cd frontend \
    && npm ci \
    && npm run build \
    && mkdir -p /opt/hermes-hudui/backend/static \
    && rm -rf /opt/hermes-hudui/backend/static/assets \
    && cp -R dist/. /opt/hermes-hudui/backend/static/ \
    && chown -R hermes:hermes /opt/hermes-hudui


# hudui 默认端口
EXPOSE 3001

# hermes dashboard 端口（继承自基础镜像）
EXPOSE 9119


COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/init", "/docker-entrypoint.sh"]
