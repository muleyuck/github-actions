#!/usr/bin/env bash
# Assert that every reference to the shared Composite Actions resolves and is pinned.
#
# 1. The relative references `./actions/...` used by validate.yml must point at a
#    directory that actually contains an action.yml.
# 2. The absolute references `muleyuck/github-actions/actions/...@ref` used by the
#    reusable workflows must be pinned at @v1 and must point at an existing action.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0

while read -r path; do
  [ -z "$path" ] && continue
  dir="${path#./}"
  if [ ! -f "${dir}/action.yml" ]; then
    echo "::error::local action not found: ${dir}/action.yml"
    status=1
  fi
done < <(grep -rhoE '\./actions/[a-z0-9/-]+' .github/workflows | sort -u)

while read -r ref; do
  [ -z "$ref" ] && continue
  version="${ref##*@}"
  dir="${ref%@*}"
  dir="${dir#muleyuck/github-actions/}"
  if [ "$version" != "v1" ]; then
    echo "::error::${ref} must be pinned at @v1"
    status=1
  fi
  if [ ! -f "${dir}/action.yml" ]; then
    echo "::error::${ref} points at a missing action: ${dir}/action.yml"
    status=1
  fi
done < <(grep -rhoE 'muleyuck/github-actions/actions/[a-z0-9/-]+@[A-Za-z0-9._-]+' .github/workflows | sort -u)

exit $status
