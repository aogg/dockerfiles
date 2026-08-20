# Minimal image for BrowserSkill CLI (bsk)
# The bsk binary is a statically linked musl binary — Alpine is the smallest fit.
FROM alpine:3.21

# Install minimal runtime dependencies required by the install.sh script:
#   curl   — download binaries and version.json from GitHub Releases
#   tar    — extract .tar.gz archive
#   ca-certificates — trust GitHub's HTTPS cert
# (sha256sum, uname, install, mktemp, mkdir are all provided by busybox in Alpine)
RUN apk add --no-cache curl tar ca-certificates

# Install bsk CLI via the official install script
RUN curl -fsSL https://raw.githubusercontent.com/Tencent/BrowserSkill/main/install.sh | sh

# Add bsk to PATH for subsequent build stages / runtime
ENV PATH="/root/.local/bin:${PATH}"
ENV BSK_DAEMON_WS_URL="ws://0.0.0.0:52800"

EXPOSE 52800

# Smoke test: verify bsk is installed and works
CMD bsk daemon start --foreground -vv