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

# The musl builds are statically linked, so they run on any Linux base image the
# workspace happens to use.
#
# The CLI does not travel alone. It resolves the Code Mode host by name from the
# directory its own binary sits in, bubblewrap from PATH or from beside the
# binary, and ripgrep from PATH; absent, it warns at startup, fails Code Mode
# closed, and cannot search the workspace. The package tarball is what keeps
# them a matched set - the bundled bubblewrap is usable only at the digest the
# CLI was built to expect - and it costs no more to fetch than the CLI alone.
#
# The package's own directories are flattened away. One copy in /agyn/bin
# answers every lookup: it is the directory the CLI is in and it is on the
# agent's PATH, which is where the layout would have put ripgrep anyway.
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) TARGET=x86_64-unknown-linux-musl ;; \
      arm64) TARGET=aarch64-unknown-linux-musl ;; \
      *) echo "unsupported architecture ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/codex-package.tar.gz \
      "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-package-${TARGET}.tar.gz"; \
    mkdir -p /pkg /out; \
    tar -xzf /tmp/codex-package.tar.gz -C /pkg; \
    mv /pkg/bin/codex /pkg/bin/codex-code-mode-host \
       /pkg/codex-resources/bwrap /pkg/codex-path/rg /out/; \
    chown 0:0 /out/*; \
    chmod 0755 /out/*

FROM busybox:1.37-musl AS runtime

COPY --from=fetch /out/ /opt/agyn/bin/
COPY config.json /opt/agyn/config.json

# Init containers run in order and write disjoint paths, so the three images
# compose without coordinating beyond the layout. Running as root is required:
# the emptyDir is root-owned on a fresh Pod. The copied files are world-readable
# so the main container can use them whatever user its image defines.
ENTRYPOINT ["/bin/sh", "-c", "set -e; mkdir -p /agyn/bin; cp -a /opt/agyn/bin/. /agyn/bin/; cp /opt/agyn/config.json /agyn/config.json; chmod 0644 /agyn/config.json"]
