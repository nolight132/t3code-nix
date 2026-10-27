#!/usr/bin/env bash
# Points sources.json at the latest stable and nightly T3 Code releases, using the AppImage digests GitHub records.
set -euo pipefail
cd "$(dirname "$0")"

# Prints the sources.json entry for one release object read from stdin.
entry() {
  local release tag version sri digest arch
  release=$(cat)
  tag=$(jq -r .tag_name <<<"$release")
  version=${tag#v}
  local -A hashes
  for arch in x86_64 arm64; do
    digest=$(jq -r --arg n "T3-Code-$version-$arch.AppImage" '.assets[] | select(.name == $n) | .digest' <<<"$release")
    [[ $digest == sha256:* ]] || { echo "no digest for $arch in $tag" >&2; exit 1; }
    hashes[$arch]=$(nix hash convert --hash-algo sha256 --to sri "${digest#sha256:}")
  done
  jq -n --arg v "$version" --arg x "${hashes[x86_64]}" --arg a "${hashes[arm64]}" \
    '{version: $v, hashes: {x86_64: $x, arm64: $a}}'
}

stable=$(gh api repos/pingdotgg/t3code/releases/latest | entry)
# The releases list is newest first and only nightly tags carry "-nightly.".
nightly=$(gh api 'repos/pingdotgg/t3code/releases?per_page=50' \
  --jq '[.[] | select(.prerelease and (.tag_name | contains("-nightly.")))] | first' | entry)

jq -n --argjson s "$stable" --argjson n "$nightly" '{stable: $s, nightly: $n}' > sources.json
jq -r 'to_entries[] | "t3code \(.key) \(.value.version)"' sources.json
