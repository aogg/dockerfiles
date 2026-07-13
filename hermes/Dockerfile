FROM nousresearch/hermes-agent


RUN apt update \
    && apt install -y execline \
    && rm -rf  /var/lib/apt/lists/* \


RUN echo "开始" \
    && npm install -g hermes-web-ui \
    && groupmod -g 1000 hermes \
    && usermod -g 1000 hermes \
    && id hermes \
    && hermes setup --non-interactive \
    && hermes config set dashboard.host 0.0.0.0 \
    && hermes config set dashboard.port 9119 \
    && hermes config set dashboard.basic_auth.username admin-hermes \
    # 密码admin
    && hermes config set dashboard.basic_auth.password "123456" \
    # 网关开关
    && hermes config set gateway.allow_all_users true \
    && hermes config set approvals.mode off \
    && echo "配置完成" \
    && mv /opt/data /opt/data.bak \
    && echo "完成"


COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/init", "/docker-entrypoint.sh"]
