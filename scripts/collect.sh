#!/usr/bin/env bash
# Downloads the Linux packages of every published release of the core and the Linux client into $1/stable and
# $1/testing: stable holds releases, testing also holds prereleases. Needs GH_TOKEN for the GitHub CLI.
set -euo pipefail

out=${1:?usage: collect.sh DIR}
mkdir -p "$out/stable" "$out/testing"

# Repository, then the release asset patterns of its packages.
sources=(
  "contr-hq/contr contr-daemon_*_amd64.deb contr-daemon-*.x86_64.rpm"
  "contr-hq/contr-linux contr_*_amd64.deb contr-[0-9]*.x86_64.rpm"
)

for source in "${sources[@]}"; do
  read -r -a words <<<"$source"
  repo=${words[0]}
  patterns=("${words[@]:1}")
  gh api --paginate "repos/$repo/releases" \
    --jq '.[] | select(.draft | not) | "\(.tag_name) \(.prerelease)"' |
    while read -r tag prerelease; do
      for channel in testing stable; do
        [[ "$channel" == stable && "$prerelease" == true ]] && continue
        args=()
        for pattern in "${patterns[@]}"; do args+=(--pattern "$pattern"); done
        # Any failure other than a release without packages stops the run, so a partial set is never published.
        if ! error=$(gh release download "$tag" --repo "$repo" --dir "$out/$channel" --skip-existing "${args[@]}" 2>&1); then
          [[ "$error" == *"no assets match"* ]] || { echo "$repo $tag: $error" >&2; exit 1; }
          echo "$repo $tag has no Linux packages"
        fi
      done
    done
done
