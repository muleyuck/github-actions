# Usage guide

Every reusable workflow is referenced through the `v1` tag.

## Assumptions

`ci-rust.yml`, `ci-go.yml` and `ci-node-pnpm.yml` read the tool versions from
the consumer's `mise.toml`. The workflow never pins a version itself.

They run `make test` by default. Override it with `test-command`.

## permissions

**Declare `permissions` on the calling job.** A reusable workflow can only
downgrade the token it is handed — it can never elevate it. Calling one from a
job with no `permissions` block under a workflow-level `permissions: {}` makes
the called job's requested permissions an elevation, and the run fails
validation before a single step executes.

| Workflow | permissions required on the calling job |
| --- | --- |
| `ci-rust.yml` / `ci-go.yml` / `ci-node-pnpm.yml` / `ci-lua-neovim.yml` | `contents: read` |
| `release-please.yml` | `contents: write` and `pull-requests: write` |

## ci-rust.yml

| input | type | default | description |
| --- | --- | --- | --- |
| `test-command` | string | `make test` | Command that runs the tests |
| `install-args` | string | `rust` | Arguments passed to `mise install` |

```yaml
name: unit-test
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
permissions: {}
jobs:
  ci:
    permissions:
      contents: read
    uses: muleyuck/github-actions/.github/workflows/ci-rust.yml@v1
```

`install-args` defaults to `rust` so that tools in `mise.toml` that build from
source, such as `cargo:cargo-dist`, are not installed in CI.

## ci-go.yml

| input | type | default | description |
| --- | --- | --- | --- |
| `test-command` | string | `make test` | Command that runs the tests |
| `install-args` | string | `go golangci-lint` | Arguments passed to `mise install` |

```yaml
jobs:
  ci:
    permissions:
      contents: read
    uses: muleyuck/github-actions/.github/workflows/ci-go.yml@v1
```

Linting is expected to run inside `make test` as `golangci-lint run ./...`.
Repositories whose `Makefile` has no `test` target (gh-issue-clone, for
example) should add one or pass `test-command`.

## ci-node-pnpm.yml

| input | type | default | description |
| --- | --- | --- | --- |
| `test-command` | string | `make test` | Command that runs the tests |
| `install-args` | string | `node pnpm` | Arguments passed to `mise install` |

```yaml
jobs:
  ci:
    permissions:
      contents: read
    uses: muleyuck/github-actions/.github/workflows/ci-node-pnpm.yml@v1
```

The composite action already runs `pnpm install --frozen-lockfile`, so the
consumer does not need to.

## ci-lua-neovim.yml

| input | type | default | description |
| --- | --- | --- | --- |
| `lua-paths` | string | `lua/ plugin/` | Paths for luacheck and stylua |
| `test-command` | string | `make test` | Command that runs the tests |
| `neovim-version` | string | `stable` | Version of Neovim used for the tests |

```yaml
jobs:
  ci:
    permissions:
      contents: read
    uses: muleyuck/github-actions/.github/workflows/ci-lua-neovim.yml@v1
```

Neovim plugins carry no `mise.toml`, so this is the one template that does not
use mise.

## release-please.yml

| input | type | default | description |
| --- | --- | --- | --- |
| `config-file` | string | `.github/release-please-config.json` | Config file |
| `manifest-file` | string | `.github/.release-please-manifest.json` | Manifest file |
| `update-stable-tag` | boolean | `false` | Move the `stable` tag on release |

| output | description |
| --- | --- |
| `release_created` | `'true'` when a release was created |
| `tag_name` | Name of the created tag |
| `version` | Version that was released |

To keep the existing "run after unit-test succeeds" arrangement:

```yaml
name: release-please
on:
  workflow_run:
    workflows: [unit-test]
    types: [completed]
    branches: [main]
permissions: {}
jobs:
  release-please:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    permissions:
      contents: write
      pull-requests: write
    uses: muleyuck/github-actions/.github/workflows/release-please.yml@v1
```

The Neovim plugins (conflux.nvim and jikan.nvim) use a `stable` tag:

```yaml
jobs:
  release-please:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    permissions:
      contents: write
      pull-requests: write
    uses: muleyuck/github-actions/.github/workflows/release-please.yml@v1
    with:
      update-stable-tag: true
```

`secrets: inherit` is not needed. `GITHUB_TOKEN` is passed to a reusable
workflow automatically.

Follow-up jobs — goreleaser, the browser extension zip release and so on —
stay in the consumer repository and read this workflow's outputs through
`needs`.

```yaml
  goreleaser:
    needs: release-please
    if: ${{ needs.release-please.outputs.release_created == 'true' }}
    ...
```

Compare against `'true'`. `release_created` is unset rather than `'false'` when
no release is created, so `!= 'false'` does not work.

## Migration targets

| Workflow | Repositories |
| --- | --- |
| `ci-rust.yml` | jqc, edio |
| `ci-lua-neovim.yml` | conflux.nvim, jikan.nvim |
| `ci-node-pnpm.yml` | cmdrop, SnapLayer, Text2QR, mermove-for-github |
| `ci-go.yml` | gh-issue-clone, linippet, Go-Echo-Windows-Service |
| `release-please.yml` | conflux.nvim, jikan.nvim, edio, jqc, linippet, SnapLayer, mermove-for-github, Go-Echo-Windows-Service |

## Out of scope for now

- `publish-npm` and `publish-crates` — no repository publishes to either today
- `audit-*` and `vulnerability-check` — SnapLayer, edio, jqc, linippet
- `deploy-pages`, `deploy-cloudflare`, `deploy-ecs`
- Browser extension releases (SnapLayer, Text2QR, mermove-for-github)
- goreleaser releases (linippet, Go-Echo-Windows-Service)
- The `release.yml` generated by cargo-dist — `dist init` regenerates it, so it
  is deliberately not shared
