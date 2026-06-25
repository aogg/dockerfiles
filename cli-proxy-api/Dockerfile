FROM eceasy/cli-proxy-api

# 安装基础工具和 Node.js
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.npm

