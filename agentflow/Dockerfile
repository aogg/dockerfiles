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
        @anthropic-ai/claude-code \
        @openai/codex \
    && npm list -g \
        @anthropic-ai/claude-code \
        @openai/codex \
    && useradd -m -g root -s /bin/bash claude \
    && echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && chown -R claude:root /usr/local/lib/node_modules \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.npm

# /root/.agentflow/data/agentflow.env
RUN curl -fsSL https://agentflow.geili.ai/installer/getagentflow.sh | bash \
    && sed -i "s/^HOST=.*/HOST=0.0.0.0/" /root/.agentflow/data/agentflow.env \
    && sed -i "s/^host=.*/host=0.0.0.0/" /root/.agentflow/data/agentflow.env \
    && cat /root/.agentflow/data/agentflow.env

ENV ANTHROPIC_BASE_URL ""
ENV ANTHROPIC_AUTH_TOKEN ""

USER claude

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

# CMD ["/root/.agentflow/bin/agentflow", "start"]
