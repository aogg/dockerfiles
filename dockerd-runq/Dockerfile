
FROM docker:dind

RUN apk add --no-cache make git \
    && cd / \
    && git clone --recurse-submodules https://github.com/gotoz/runq.git \
    && cd runq \
    && make release \
    && make release-install \
    && echo '结束'