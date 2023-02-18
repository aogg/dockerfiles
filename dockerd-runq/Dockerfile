
FROM docker:dind

# github-ci编译报错，无法实时编译需要虚拟机相关的

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