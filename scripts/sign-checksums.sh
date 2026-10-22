#!/usr/bin/env bash
# Publishes every release's SHA256SUMS of the Contr repositories under $1/checksums/<repository>/<tag>/ with a
# detached signature by the key build-repos.sh uses. Needs GH_TOKEN for the GitHub CLI.
set -euo pipefail

site=${1:?usage: sign-checksums.sh SITE}
key=${SIGNING_KEY:?fingerprint of the signing key}
passphrase=${SIGNING_PASSPHRASE_FILE:?file holding the passphrase of the signing key}

for repo in contr contr-linux contr-windows; do
  gh api --paginate "repos/contr-hq/$repo/releases" --jq '.[] | select(.draft | not) | .tag_name' |
    while read -r tag; do
      dir="$site/checksums/$repo/$tag"
      mkdir -p "$dir"
      # Any failure other than a release without checksums stops the run, so a partial set is never published.
      if ! error=$(gh release download "$tag" --repo "contr-hq/$repo" --dir "$dir" --pattern SHA256SUMS 2>&1); then
        [[ "$error" == *"no assets match"* ]] || { echo "$repo $tag: $error" >&2; exit 1; }
        rmdir "$dir"
        continue
      fi
      gpg --batch --yes --pinentry-mode loopback --passphrase-file "$passphrase" --local-user "$key" \
        --armor --detach-sign --output "$dir/SHA256SUMS.asc" "$dir/SHA256SUMS"
    done
done
