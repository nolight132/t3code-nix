#!/usr/bin/env bash
# Points sources.json at the latest stable T3 Code release, using the AppImage digests GitHub records.
set -euo pipefail
cd "$(dirname "$0")"

release=$(gh api repos/pingdotgg/t3code/releases/latest)
tag=$(jq -r .tag_name <<<"$release")
version=${tag#v}

sri() {
  local digest
  digest=$(jq -r --arg n "T3-Code-$version-$1.AppImage" '.assets[] | select(.name == $n) | .digest' <<<"$release")
  [[ $digest == sha256:* ]] || { echo "no digest for $1 in $tag" >&2; exit 1; }
  nix hash convert --hash-algo sha256 --to sri "${digest#sha256:}"
}

jq -n --arg v "$version" --arg x "$(sri x86_64)" --arg a "$(sri arm64)" \
  '{version: $v, hashes: {x86_64: $x, arm64: $a}}' > sources.json
echo "t3code $version"
