FROM node:24

# 安装基础工具、Docker CLI 和 OpenSSH
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        curl \
        procps \
        sudo \
        openssh-server \
        openssh-client \
        gnupg \
        lsb-release \
    # 安装 Docker CLI only
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    # 创建 docker 组
    && groupadd -f docker \
    # 配置 git 和 npm
    && git config --global --add safe.directory '*' \
    && npm install -g \
        @cloudcli-ai/cloudcli@latest \
        opencode-ai \
        task-master-ai \
        @anthropic-ai/claude-code \
        @google/gemini-cli \
        @openai/codex \
    && npm list -g \
        @cloudcli-ai/cloudcli@latest \
        opencode-ai \
        task-master-ai \
        @anthropic-ai/claude-code \
        @google/gemini-cli \
        @openai/codex \
    # 配置用户权限
    && usermod -aG root node \
    && usermod -aG docker node \
    && mkhomedir_helper node \
    && echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.npm

# SSHD 环境变量配置
ENV SSHD_PORT=22
ENV SSHD_PASSWORD=''

ENV WORKSPACES_ROOT=/

ENV ANTHROPIC_BASE_URL ""
ENV ANTHROPIC_AUTH_TOKEN ""

ENV GOOGLE_GEMINI_BASE_URL ""
ENV GEMINI_API_KEY ""

# 复制 SSHD 初始化脚本
ADD ./common/open-sshd-passwd.sh /
ADD ./claudecodeui/docker-entrypoint.sh /
# RUN chmod +x /open-sshd-passwd.sh /docker-entrypoint.sh

# 设置 entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["cloudcli"]
