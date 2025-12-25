
ARG LATEST_FROM_BASE=scratch

FROM golang AS builder

ARG LATEST_FROM_BASE

COPY ./src /code

RUN cd /code \
    && CGO_ENABLED=0 GOOS=linux go build -tags netgo -v -o /http-shell . \
    && chmod +x /http-shell \
    && ls -al /http-shell \
    && echo '编译结束'


FROM ${LATEST_FROM_BASE}

ENV PATH=$PATH:/usr/bin:/usr/local/sbin/

COPY --from=builder /http-shell /http-shell

EXPOSE 8080/TCP

VOLUME [ "/usr/local/sbin/" ]

ENTRYPOINT [ "/http-shell" ] 