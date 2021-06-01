FROM debian

RUN apt-get update && apt-get install -y qemu-utils && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
ENTRYPOINT ["qemu-img"]
CMD ["--help"]
