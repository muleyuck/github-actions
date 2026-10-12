#!/usr/bin/env bash
# Renders a Homebrew formula or cask template into $RUNNER_TEMP/homebrew/<tap path>.
# Inputs (environment): TEMPLATE, TAP_PATH, VERSION, and SHA256 — newline-separated
# NAME=path lines whose file checksums replace @NAME@. Writes path=<file> to $GITHUB_OUTPUT.
set -euo pipefail
# bash 5.2 turns & in a ${var//pattern/replacement} replacement into the match.
# macOS /bin/bash 3.2 has no such option, hence the || true.
shopt -u patsub_replacement 2>/dev/null || true

fail() {
  echo "::error::$1" >&2
  exit 1
}

# brew style applies the Homebrew cops only under Formula/ and Casks/.
[[ $TAP_PATH =~ ^(Formula|Casks)/[^/[:cntrl:]]+\.rb$ ]] ||
  fail "tap-path must be Formula/<name>.rb or Casks/<name>.rb, got: $TAP_PATH"
[[ -n $VERSION ]] || fail "version is empty"
[[ -f $TEMPLATE ]] || fail "template not found: $TEMPLATE"

text=$(<"$TEMPLATE")
text=${text//"@VERSION@"/$VERSION}

lineno=0
while IFS= read -r line || [[ -n $line ]]; do
  lineno=$((lineno + 1))
  if [[ -z ${line//[[:space:]]/} ]]; then
    continue
  fi
  [[ $line =~ ^([[:upper:][:digit:]_]+)=(.+)$ ]] ||
    fail "sha256 line $lineno is not NAME=path: $line"
  name=${BASH_REMATCH[1]}
  file=${BASH_REMATCH[2]}
  [[ -f $file ]] || fail "sha256 line $lineno: file not found: $file"
  [[ $text == *"@$name@"* ]] || fail "sha256 line $lineno: $TEMPLATE has no @$name@"
  sum=$(shasum -a 256 <"$file" | cut -d ' ' -f 1)
  text=${text//"@$name@"/$sum}
done <<<"$SHA256"

if leftovers=$(grep -nE '@[[:upper:][:digit:]_]+@' <<<"$text"); then
  echo "$leftovers" >&2
  fail "$TEMPLATE has placeholders with no value"
fi

out="$RUNNER_TEMP/homebrew/$TAP_PATH"
mkdir -p "$(dirname "$out")"
printf '%s\n' "$text" >"$out"
brew style "$out"
echo "path=$out" >>"$GITHUB_OUTPUT"
