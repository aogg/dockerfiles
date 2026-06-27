FROM nousresearch/hermes-agent



RUN echo "开始" \
    # && npm install -g hermes-web-ui \
    && groupmod -g 1000 hermes \
    && usermod -g 1000 hermes \
    && id hermes \
    && hermes setup --non-interactive \
    && hermes config set dashboard.host 0.0.0.0 \
    && hermes config set dashboard.port 9119 \
    && hermes config set dashboard.basic_auth.username admin-hermes \
    # 密码admin
    && hermes config set dashboard.basic_auth.password_hash "scrypt$16384$8$1$9iN2RGlOKJJ6TaU+7mHDhQ==$iwW/llJk6aStTPCeMuSwmLcY8UJqzXxwAgI6pKzBGng=" \
    # 网关开关
    && hermes config set gateway.allow_all_users true \
    && echo "配置完成" \
    && mv /opt/data /opt/data.bak \
    && echo "完成"


COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/init", "/docker-entrypoint.sh"]
