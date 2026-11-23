#!/usr/bin/env bash
# Points sources.json at the latest stable and nightly T3 Code releases, using the AppImage digests GitHub records.
set -euo pipefail
cd "$(dirname "$0")"

# Prints the sources.json entry for one release object read from stdin.
# AppImages are matched by their architecture suffix because upstream has named them both
# T3-Code-<version>-<arch>.AppImage and T3-Code[-Nightly]-<arch>.AppImage.
entry() {
  local release tag version asset digest arch
  release=$(cat)
  tag=$(jq -r .tag_name <<<"$release")
  version=${tag#v}
  local -A urls hashes
  for arch in x86_64 arm64; do
    asset=$(jq -c --arg suffix "-$arch.AppImage" \
      '[.assets[] | select((.name | startswith("T3-Code-")) and (.name | endswith($suffix)))] | first' <<<"$release")
    digest=$(jq -r '.digest // empty' <<<"$asset")
    [[ $digest == sha256:* ]] || { echo "no AppImage digest for $arch in $tag" >&2; exit 1; }
    urls[$arch]=$(jq -r .browser_download_url <<<"$asset")
    hashes[$arch]=$(nix hash convert --hash-algo sha256 --to sri "${digest#sha256:}")
  done
  jq -n --arg v "$version" \
    --arg xu "${urls[x86_64]}" --arg xh "${hashes[x86_64]}" \
    --arg au "${urls[arm64]}" --arg ah "${hashes[arm64]}" \
    '{version: $v, sources: {x86_64: {url: $xu, hash: $xh}, arm64: {url: $au, hash: $ah}}}'
}

stable=$(gh api repos/pingdotgg/t3code/releases/latest | entry)
# The releases list is newest first and only nightly tags carry "-nightly.".
nightly=$(gh api 'repos/pingdotgg/t3code/releases?per_page=50' \
  --jq '[.[] | select(.prerelease and (.tag_name | contains("-nightly.")))] | first' | entry)

jq -n --argjson s "$stable" --argjson n "$nightly" '{stable: $s, nightly: $n}' > sources.json
jq -r 'to_entries[] | "t3code \(.key) \(.value.version)"' sources.json
