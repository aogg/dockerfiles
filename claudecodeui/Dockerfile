FROM node:24

# 安装基础工具和 Node.js
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        curl \
        procps \
    && npm install -g \
        @siteboon/claude-code-ui \
        @anthropic-ai/claude-code \
        @google/gemini-cli \
        @openai/codex \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.npm

ENV WORKSPACES_ROOT=/

ENV ANTHROPIC_BASE_URL ""
ENV ANTHROPIC_AUTH_TOKEN ""

ENV GOOGLE_GEMINI_BASE_URL ""
ENV GEMINI_API_KEY ""

CMD ["cloudcli"]
