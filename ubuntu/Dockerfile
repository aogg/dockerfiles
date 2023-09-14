FROM ubuntu

ARG APT_ARGS=""

# --no-cache没有/var/cache/apk
RUN apt update && apt install -y $APT_ARGS \
  && rm -rf /var/lib/apt/lists/*


CMD tail -f /etc/hosts