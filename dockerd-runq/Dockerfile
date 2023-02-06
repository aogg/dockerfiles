
FROM docker:dind

RUN echo '开始' && (dockerd-entrypoint.sh &) \
    && id \
    && sleep 2 \
    && apk add --no-cache make git \
    && cd / \
    && git clone --recurse-submodules https://github.com/gotoz/runq.git \
    && cd runq \
    && make release \
    && make release-install \
    && echo '结束'