
ARG LATEST_FROM_BASE=scratch

FROM golang as builder

ARG LATEST_FROM_BASE

COPY http_hosts.go /http_hosts.go

RUN cd / \
    && CGO_ENABLED=0 GOOS=linux go build -tags netgo -v -o http-hosts /http_hosts.go \
    && chmod +x /http-hosts \
    && ls -al /http-hosts


FROM ${LATEST_FROM_BASE}

ENV PATH=$PATH:/usr/bin:/usr/local/sbin/

COPY --from=builder /http-hosts /http-hosts

EXPOSE 8080/TCP

RUN mkdir /data/

VOLUME [ "/usr/local/sbin/" ]

ENTRYPOINT [ "/http-hosts" ] 