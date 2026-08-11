# github-actions

Shared GitHub Actions library for the muleyuck repositories.

- **Reusable Workflow** (`.github/workflows/`) — CI/CD templates, one per project type
- **Composite Action** (`actions/`) — the technical parts the workflows are built from

Consumers reference the `v1` tag. Never reference `main`.

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

Declare `permissions` on the calling job — a reusable workflow can only
downgrade the token it is handed. See [docs/usage.md](docs/usage.md) for the
input reference, the permissions each workflow needs, and the migration steps.

## Reusable workflows

| File | Purpose |
| --- | --- |
| `ci-rust.yml` | Lint, build and test a Rust project |
| `ci-go.yml` | Lint, build and test a Go project |
| `ci-node-pnpm.yml` | Lint, build and test a Node.js project that uses pnpm |
| `ci-lua-neovim.yml` | Run luacheck, stylua and the test suite of a Neovim plugin |
| `release-please.yml` | Create the release PR and tag the release with release-please |

## Composite actions

| Path | Purpose |
| --- | --- |
| `actions/common/release-please` | Run release-please itself |
| `actions/rust/setup` | Install the Rust toolchain and restore the cargo cache |
| `actions/go/setup` | Install Go and golangci-lint and restore the module cache |
| `actions/node/setup` | Install Node and pnpm, cache the store, install dependencies |
| `actions/lua/luacheck` | Install and run luacheck |
| `actions/lua/stylua` | Check formatting with stylua |
| `actions/lua/setup-neovim` | Install Neovim for the test suite |

## Versioning

`v1` is a moving tag. `release.yml` runs after `validate.yml` succeeds on
`main`: release-please cuts the `v1.x.y` tag from the conventional commits, and
the workflow then moves `v1` onto that commit. Nothing is tagged by hand.

Backwards compatible changes therefore reach every consumer without a pull
request. The gate for them is `validate.yml`, not review in each repository.

Only commit types that appear in the changelog produce a release, so a change
consumers actually run has to be committed as `feat`, `fix`, `perf` or `deps`.
release-please skips the release entirely when the changelog would be empty,
which leaves `v1` where it is — the right outcome for `ci`, `style`, `docs`,
`refactor` and `chore`, and a silent no-op for anything else.

Raise the major version only for a breaking change — removing or renaming an
input or output, changing a default, or requiring a permission the calling job
does not already grant. Leave `v1` where it is, tag `v2`, and every consumer
gets a Dependabot pull request to move from `@v1` to `@v2`.

A reusable workflow references a composite action as
`muleyuck/github-actions/actions/<path>@v1`, so moving `v1` switches the
workflow and the action together. `tests/assert-action-refs.sh` enforces that
pinning in CI, and those references have to be rewritten when the major
version changes.

## Development

```
mise install
mise exec -- actionlint
./tests/assert-action-refs.sh
```

On push and pull request, `validate.yml` runs actionlint, the reference check,
and the composite actions against the minimal projects under `tests/fixtures/`.
