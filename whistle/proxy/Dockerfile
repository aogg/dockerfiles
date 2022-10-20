FROM adockero/whistle

COPY docker_cmd.sh /usr/local/bin/
COPY .whistle.js /usr/local/lib/node_modules/whistle/


ENV ADMIN_USERNAME=admin \
    ADMIN_PASSWORD=admin \
    GUEST_USERNAME=guest \
    GUEST_PASSWORD=guest \
    UI_PORT=8999 \
    PROXY_PORT=8899 \
    MORE_OPTIONS="" \
    LOCAL_RULE='' \
    WHISTLE_MORE_ARGS='' \
    PROXY_ADDR='nginx'





CMD docker_cmd.sh
