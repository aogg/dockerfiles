
FROM golang as builder

COPY http_shell.go /http_shell.go

RUN cd / \
    && go build -v /http_shell.go \
    && chmod +x /http_shell


FROM scratch

ENV PATH=$PATH:/usr/bin

COPY --from=builder /http_shell /http_shell

CMD /http_shell