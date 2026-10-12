#!/usr/bin/env bash
# actionlint does not verify action reference paths at all, and the reusable
# workflows are never executed here, so a typo in one of them would only
# surface in the consumer repositories. Check both forms of reference instead:
# each must resolve to an action.yml, and remote self-references must be at @v1.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

status=0
fail() {
  echo "::error::$1"
  status=1
}

while read -r ref; do
  dir=${ref#./}
  dir=${dir#muleyuck/github-actions/}
  if [[ $ref == *@* ]]; then
    [[ ${ref##*@} == v1 ]] || fail "$ref must be pinned at @v1"
    dir=${dir%@*}
  fi
  [[ -f $dir/action.yml ]] || fail "$ref does not resolve to $dir/action.yml"
done < <(grep -rhoE '(\./|muleyuck/github-actions/)actions/[a-z0-9/-]+(@[A-Za-z0-9._-]+)?' .github/workflows | sort -u)

# The homebrew actions run a shared script by path, which neither actionlint
# nor the reference check above can see.
[[ -f actions/homebrew/lib/render.sh ]] ||
  fail "actions/homebrew/lib/render.sh is missing"
for action in render publish; do
  grep -qF 'run: bash "$GITHUB_ACTION_PATH/../lib/render.sh"' "actions/homebrew/$action/action.yml" ||
    fail "actions/homebrew/$action/action.yml must run \$GITHUB_ACTION_PATH/../lib/render.sh"
done

exit $status
