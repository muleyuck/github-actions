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
| `audit-rust.yml` / `audit-go.yml` / `audit-node-pnpm.yml` | `contents: read` |
| `deploy-pages-node-pnpm.yml` | `contents: read`, `pages: write` and `id-token: write` |
| `release-please.yml` | `contents: write` and `pull-requests: write` |

## ci-rust.yml

| input | type | default | description |
| --- | --- | --- | --- |
| `test-command` | string | `make test` | Command that runs the tests |
| `install-args` | string | `rust` | Arguments passed to `mise install` |
| `runs-on` | string | `ubuntu-latest` | Runner label the job runs on |

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

## audit-rust.yml, audit-go.yml, audit-node-pnpm.yml

| input | workflow | type | default | description |
| --- | --- | --- | --- | --- |
| `audit-level` | `audit-node-pnpm.yml` | string | `high` | Lowest severity that fails the check |
| `go-package` | `audit-go.yml` | string | `./...` | Package pattern passed to govulncheck |

`audit-rust.yml` takes no inputs.

An audit result changes when a new advisory is published, not only when the
code changes, so give these a schedule. A reusable workflow cannot carry its
own `schedule:` — the trigger has to be declared by the caller.

```yaml
name: audit
on:
  schedule:
    - cron: "0 0 * * 1"
  pull_request:
    branches: [main]
  workflow_dispatch:
permissions: {}
jobs:
  audit:
    permissions:
      contents: read
    uses: muleyuck/github-actions/.github/workflows/audit-rust.yml@v1
```

Keeping the audit out of `ci-*.yml` is deliberate. It goes red for reasons that
have nothing to do with the change under review, so whether it blocks a merge
should be a separate decision.

`audit-rust.yml` builds cargo-audit from source, which takes around two
minutes. The other two install nothing beyond the toolchain.

## deploy-pages-node-pnpm.yml

| input | type | default | description |
| --- | --- | --- | --- |
| `build-command` | string | `pnpm build` | Command that builds the static site |
| `artifact-path` | string | `dist` | Directory uploaded to GitHub Pages |
| `install-args` | string | `node pnpm` | Arguments passed to `mise install` |

| output | description |
| --- | --- |
| `page-url` | URL the site was deployed to |

```yaml
name: deploy-pages
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions: {}
concurrency:
  group: pages
  cancel-in-progress: false
jobs:
  deploy:
    permissions:
      contents: read
      pages: write
      id-token: write
    uses: muleyuck/github-actions/.github/workflows/deploy-pages-node-pnpm.yml@v1
```

Set the Pages source to **GitHub Actions** in the repository settings first.
With the source left at "Deploy from a branch", `actions/deploy-pages` fails.

`concurrency` belongs to the caller. A reusable workflow's own `concurrency` is
a separate group from the caller's, so declaring it here would not serialise
two runs of the same consumer. `group: pages` with `cancel-in-progress: false`
lets a queued deployment finish rather than being cancelled halfway.

The build runs through `bash -c`, so a build that needs more than one command
can be passed as one string:

```yaml
    with:
      build-command: pnpm demo:build && cp registry.json demo/dist/registry.json
      artifact-path: demo/dist
```

A project site is served from `https://<user>.github.io/<repo>/`, not from the
domain root. Bundlers need to be told: Vite takes `base`, Next.js `basePath`.
Absolute paths written by hand in application code are not rewritten by the
bundler and have to go through `import.meta.env.BASE_URL` or its equivalent.

This template assumes a pnpm build. A repository that uploads a directory as it
stands, with no build step and no Node at all, is better off with the three
Pages actions written out in place.

## release-please.yml

| input | type | default | description |
| --- | --- | --- | --- |
| `config-file` | string | `.github/release-please-config.json` | Config file |
| `manifest-file` | string | `.github/.release-please-manifest.json` | Manifest file |
| `path` | string | `.` | Package path whose outputs are returned |
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

When the released package is not at the repository root, release-please
prefixes its outputs with the package path. Set `path` to that package's key in
`packages` of the config file, written exactly the same way — `./packages/foo`
or `packages/foo/` for a `packages/foo` key matches nothing, and the outputs
come back empty without an error:

```yaml
    uses: muleyuck/github-actions/.github/workflows/release-please.yml@v1
    with:
      path: packages/foo
```

`secrets: inherit` is not needed. `GITHUB_TOKEN` is passed to a reusable
workflow automatically.

Follow-up jobs — goreleaser, the browser extension zip release and so on —
stay in the consumer repository and read this workflow's outputs through
`needs`. A job that publishes to the Homebrew tap ends with
[`actions/homebrew/publish`](#actionshomebrewpublish).

```yaml
  goreleaser:
    needs: release-please
    if: ${{ needs.release-please.outputs.release_created == 'true' }}
    ...
```

Compare against `'true'`. `release_created` is unset rather than `'false'` when
no release is created, so `!= 'false'` does not work.

## actions/homebrew/publish

Renders a formula or cask template and pushes it to the tap,
muleyuck/homebrew-tap. The consumer
keeps building the archives and attaching them to the release; publish does
the rest.

- **macOS runners only.** It runs `brew style` on the rendered file.
- **Call it after the archives are attached to the release**, so the tap never
  points at a missing file.
- It needs a GitHub App that can write contents of the tap. It does not use
  `GITHUB_TOKEN`, so it adds nothing to the calling job's `permissions`.
- The tap is checked out to `.homebrew-tap` in the workspace and left there.

| input | required | default | description |
| --- | --- | --- | --- |
| `template` | yes | | Template path. `@VERSION@` and each `@NAME@` from `sha256` are replaced |
| `tap-path` | yes | | `Formula/<name>.rb` or `Casks/<name>.rb` |
| `version` | yes | | Replaces `@VERSION@`; the tap commit is `<name> <version>` |
| `sha256` | no | `""` | Newline-separated `NAME=path`; each file's SHA-256 replaces `@NAME@` |
| `client-id` | yes | | GitHub App client ID |
| `private-key` | yes | | GitHub App private key |

It fails before touching the tap when a `sha256` line is not `NAME=path`, a
file is missing, the template has no `@NAME@` for a given name, or a
placeholder is left without a value.

A formula with one archive per platform (jqc):

```yaml
      - uses: muleyuck/github-actions/actions/homebrew/publish@v1
        with:
          template: packaging/jqc.rb.in
          tap-path: Formula/jqc.rb
          version: ${{ env.VERSION }}
          sha256: |
            SHA256_AARCH64_APPLE_DARWIN=dist/jqc-aarch64-apple-darwin.tar.xz
            SHA256_X86_64_APPLE_DARWIN=dist/jqc-x86_64-apple-darwin.tar.xz
            SHA256_AARCH64_UNKNOWN_LINUX_GNU=dist/jqc-aarch64-unknown-linux-gnu.tar.xz
            SHA256_X86_64_UNKNOWN_LINUX_GNU=dist/jqc-x86_64-unknown-linux-gnu.tar.xz
          client-id: ${{ secrets.TAP_APP_CLIENT_ID }}
          private-key: ${{ secrets.TAP_APP_PRIVATE_KEY }}
```

A cask (turnray):

```yaml
      - uses: muleyuck/github-actions/actions/homebrew/publish@v1
        with:
          template: packaging/turnray.rb.in
          tap-path: Casks/turnray.rb
          version: ${{ env.VERSION }}
          sha256: SHA256=target/turnray-${{ env.VERSION }}.zip
          client-id: ${{ secrets.TAP_APP_CLIENT_ID }}
          private-key: ${{ secrets.TAP_APP_PRIVATE_KEY }}
```

`actions/homebrew/render` is the first half on its own (render and
`brew style`, output `path`); validate.yml tests it with
`tests/fixtures/homebrew`.

## Migration targets

| Workflow | Repositories |
| --- | --- |
| `ci-rust.yml` | jqc, edio |
| `ci-lua-neovim.yml` | conflux.nvim, jikan.nvim |
| `ci-node-pnpm.yml` | cmdrop, SnapLayer, Text2QR, mermove-for-github |
| `ci-go.yml` | gh-issue-clone, linippet |
| `audit-rust.yml` | jqc, edio |
| `audit-node-pnpm.yml` | SnapLayer, and cmdrop, Text2QR, mermove-for-github, which have no audit today |
| `audit-go.yml` | linippet, and gh-issue-clone, which have no audit today |
| `release-please.yml` | conflux.nvim, jikan.nvim, edio, jqc, linippet, SnapLayer, mermove-for-github |
| `deploy-pages-node-pnpm.yml` | cmdrop |
| `actions/homebrew/publish` | jqc, turnray |

## Out of scope for now

- `publish-npm` and `publish-crates` — no repository publishes to either today
- `deploy-cloudflare`, `deploy-ecs`
- Browser extension releases (SnapLayer, Text2QR, mermove-for-github)
- goreleaser releases (linippet)
- The `release.yml` generated by cargo-dist — `dist init` regenerates it, so it
  is deliberately not shared
