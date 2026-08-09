# agyn-runtime-codex

The [agent runtime image](https://github.com/agynio/architecture/blob/main/architecture/agent-init.md#agent-runtime-images)
for the Codex CLI: one agent CLI, the helpers it resolves by name, and the
`config.json` that describes it.

`agynd` and the `agyn` CLI are **not** in this image. They ship with the
platform and arrive in the same `/agyn/bin` volume from their own init images,
which is what lets this repository pin only its own CLI version — and what makes
its tags mean something in a version picker.

## Contents

```
/agyn/
├── bin/
│   ├── codex                 # the agent CLI
│   ├── codex-code-mode-host  # Code Mode host, spawned from beside the CLI
│   ├── bwrap                 # bubblewrap, the sandbox the CLI shells out to
│   └── rg                    # ripgrep, what the CLI searches the workspace with
└── config.json               # {"sdk": "codex", "bin": "bin/codex"}
```

`agynd` reads `config.json` at startup to learn which SDK module to use and
where the binary is. The Orchestrator sets none of it.

The helpers all come out of the same `codex-package` tarball as the CLI, so they
are one matched set rather than four independent pins. Codex looks for the Code
Mode host in the directory its own binary is in, and for bubblewrap and ripgrep
on PATH — `/agyn/bin` is both — falling back for bubblewrap to a bundled copy
beside the CLI whose digest it verifies against the one it was built with.

## Releasing

Bump `CODEX_VERSION` in `VERSION`, then tag. Tags correspond to Codex versions,
so `v0.47.0` publishes `ghcr.io/agynio/agyn-runtime-codex:0.47.0`.

## The other runtimes

`agyn-runtime-claude` and `agyn-runtime-agn` are the same shape: a Dockerfile, a
`config.json`, a version pin, and this release workflow. Claude Code's musl
build additionally needs `libgcc` and `libstdc++` bundled alongside the binary.
