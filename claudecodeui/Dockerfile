FROM node:24

# 安装基础工具和 Node.js
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        curl \
    && npm install -g \
        @siteboon/claude-code-ui \
        @anthropic-ai/claude-code \
        @google/gemini-cli \
        @openai/codex \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.npm

CMD ["cloudcli"]
