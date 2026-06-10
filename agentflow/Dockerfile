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


USER claude

# /root/.agentflow/data/agentflow.env
RUN curl -fsSL https://agentflow.geili.ai/installer/getagentflow.sh | bash \
    && /home/claude/.agentflow/bin/agentflow start \
    && echo "export PATH=\"\$HOME/.agentflow/bin:\$PATH\"" | sudo tee -a /etc/profile \
    # && AgentFlow --help \
    && (ls -al /home/claude/.agentflow || echo 1) \
    && (sed -i "s/^HOST=.*/HOST=0.0.0.0/" /home/claude/.agentflow/data/agentflow.env || echo 1) \
    && (cat /home/claude/.agentflow/data/agentflow.env || echo 1) \
    && mkdir -p /home/claude/.agentflow/data_bak \
    && cp -a /home/claude/.agentflow/data/* /home/claude/.agentflow/data_bak \
    && echo "结束"

ENV ANTHROPIC_BASE_URL ""
ENV ANTHROPIC_AUTH_TOKEN ""

VOLUME /home/claude/.agentflow/data

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

# CMD ["/root/.agentflow/bin/agentflow", "start"]
