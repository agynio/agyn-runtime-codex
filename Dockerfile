# syntax=docker/dockerfile:1.8
#
# The Codex agent runtime. It carries one agent CLI and the config.json that
# describes it, and nothing else: agynd and the agyn CLI ship with the platform
# and arrive in the same volume from their own init images.
#
# The image describes itself. The Orchestrator sets no binary path, no SDK type
# and no CLI arguments - it treats this as an opaque reference the catalog
# resolves, exactly as it treats the workspace image. That is what makes it
# impossible for whoever registered the image to mislabel it: what runs is
# decided by what is actually inside.
ARG CODEX_VERSION

FROM alpine:3.21 AS fetch
ARG CODEX_VERSION
ARG TARGETARCH
RUN apk add --no-cache curl

# The musl build is statically linked, so it runs on any Linux base image the
# workspace happens to use. The tarball holds a single file named for its
# target triple.
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) TARGET=x86_64-unknown-linux-musl ;; \
      arm64) TARGET=aarch64-unknown-linux-musl ;; \
      *) echo "unsupported architecture ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/codex.tar.gz \
      "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-${TARGET}.tar.gz"; \
    mkdir -p /out; \
    tar -xzf /tmp/codex.tar.gz -C /out; \
    mv "/out/codex-${TARGET}" /out/codex; \
    chmod 0755 /out/codex

FROM busybox:1.37-musl AS runtime

COPY --from=fetch /out/codex /opt/agyn/codex
COPY config.json /opt/agyn/config.json

# Init containers run in order and write disjoint paths, so the three images
# compose without coordinating beyond the layout. Running as root is required:
# the emptyDir is root-owned on a fresh Pod. The copied files are world-readable
# so the main container can use them whatever user its image defines.
ENTRYPOINT ["/bin/sh", "-c", "set -e; mkdir -p /agyn/bin; cp /opt/agyn/codex /agyn/bin/codex; chmod 0755 /agyn/bin/codex; cp /opt/agyn/config.json /agyn/bin/config.json; chmod 0644 /agyn/bin/config.json"]
