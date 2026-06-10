FROM node:24

# 安装基础工具和 Node.js
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        curl \
        procps \
        sudo \
    && git config --global --add safe.directory '*' \
    && npm install -g \
        @cloudcli-ai/cloudcli@latest \
        @anthropic-ai/claude-code \
        @google/gemini-cli \
        @openai/codex \
    && npm list -g \
        @cloudcli-ai/cloudcli@latest \
        @anthropic-ai/claude-code \
        @google/gemini-cli \
        @openai/codex \
    && usermod -aG root node \
    && mkhomedir_helper node \
    && echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.npm

ENV WORKSPACES_ROOT=/

ENV ANTHROPIC_BASE_URL ""
ENV ANTHROPIC_AUTH_TOKEN ""

ENV GOOGLE_GEMINI_BASE_URL ""
ENV GEMINI_API_KEY ""

USER node

CMD ["cloudcli"]
