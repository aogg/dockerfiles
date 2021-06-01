FROM alpine

RUN apk add --update qemu-img 

ENTRYPOINT ["/usr/bin/qemu-img"]
CMD ["--help"]
