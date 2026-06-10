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
    && usermod -aG root node \
    && mkhomedir_helper node \
    && echo "node ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.npm


USER node

# /root/.agentflow/data/agentflow.env
RUN curl -fsSL https://agentflow.geili.ai/installer/getagentflow.sh | bash \
    && /home/node/.agentflow/bin/agentflow start \
    && echo "export PATH=\"\$HOME/.agentflow/bin:\$PATH\"" | sudo tee -a /etc/profile \
    # && AgentFlow --help \
    && (ls -al /home/node/.agentflow || echo 1) \
    && (sed -i "s/^HOST=.*/HOST=0.0.0.0/" /home/node/.agentflow/data/agentflow.env || echo 1) \
    && (cat /home/node/.agentflow/data/agentflow.env || echo 1) \
    && mkdir -p /home/node/.agentflow/data_bak \
    && cp -a /home/node/.agentflow/data/* /home/node/.agentflow/data_bak \
    && echo "结束"

ENV ANTHROPIC_BASE_URL ""
ENV ANTHROPIC_AUTH_TOKEN ""

VOLUME /home/node/.agentflow/data

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

# CMD ["/root/.agentflow/bin/agentflow", "start"]
