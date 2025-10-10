


# @see https://github.com/alpine-docker/multi-arch-docker-images/blob/master/mkcert/Dockerfile

FROM --platform=$BUILDPLATFORM golang:1.20-alpine AS builder

# Install dependencies
RUN apk add --no-cache \
    git \
    bash \
    gcc \
    musl-dev

# Set up working directory
WORKDIR /app

# Clone mkcert repository and checkout the latest tag
RUN git clone https://github.com/FiloSottile/mkcert.git . && \
    latest_tag=$(git describe --tags `git rev-list --tags --max-count=1`) && \
    git checkout $latest_tag

# Build mkcert binary based on target architecture
ARG TARGETPLATFORM 'linux/amd64'
RUN go env -w GOOS=linux && \
    if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      go env -w GOARCH=arm64; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
      go env -w GOARCH=amd64; \
    fi && \
    go build -ldflags "-X main.Version=$latest_tag" -o mkcert



FROM adockero/openresty-proxy:https-intercept

ENV AUTO_MKCERT=1

COPY --from=builder /app/mkcert /usr/local/bin/mkcert
COPY ./docker-run-mkcert.sh /docker-run-mkcert.sh
COPY ./mkcert.sh /mkcert.sh

VOLUME [ "/root/.local/share/mkcert/" ]

RUN apk add --no-cache \
    nss-tools \
    ca-certificates

CMD /docker-run-mkcert.sh




