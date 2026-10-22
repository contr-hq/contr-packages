#!/usr/bin/env bash
# Builds signed APT and DNF repositories under $2 from the packages collect.sh put in $1, with the GnuPG key whose
# fingerprint is $SIGNING_KEY and whose passphrase is in the file $SIGNING_PASSPHRASE_FILE.
set -euo pipefail

packages=${1:?usage: build-repos.sh PACKAGES SITE}
site=${2:?usage: build-repos.sh PACKAGES SITE}
key=${SIGNING_KEY:?fingerprint of the signing key}
passphrase=${SIGNING_PASSPHRASE_FILE:?file holding the passphrase of the signing key}
gpg_batch=(gpg --batch --yes --pinentry-mode loopback --passphrase-file "$passphrase" --local-user "$key")

mkdir -p "$site"
gpg --armor --export "$key" >"$site/KEY.asc"
gpg --export "$key" >"$site/contr.gpg"

for channel in stable testing; do
  # APT: dists/<channel> names the packages in pool/<channel>; InRelease and Release.gpg sign them.
  apt="$site/apt"
  pool="pool/$channel"
  binaries="dists/$channel/main/binary-amd64"
  mkdir -p "$apt/$pool" "$apt/$binaries"
  cp "$packages/$channel/"*.deb "$apt/$pool/" 2>/dev/null || true
  (cd "$apt" && apt-ftparchive packages "$pool" >"$binaries/Packages")
  gzip -9 --keep --force "$apt/$binaries/Packages"
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=Contr \
    -o APT::FTPArchive::Release::Label=Contr \
    -o APT::FTPArchive::Release::Suite="$channel" \
    -o APT::FTPArchive::Release::Codename="$channel" \
    -o APT::FTPArchive::Release::Architectures=amd64 \
    -o APT::FTPArchive::Release::Components=main \
    release "$apt/dists/$channel" >"$apt/dists/$channel/Release"
  "${gpg_batch[@]}" --clearsign --output "$apt/dists/$channel/InRelease" "$apt/dists/$channel/Release"
  "${gpg_batch[@]}" --armor --detach-sign --output "$apt/dists/$channel/Release.gpg" "$apt/dists/$channel/Release"

  # DNF: each package carries its signature, and repomd.xml.asc signs the metadata.
  rpm_dir="$site/rpm/$channel"
  mkdir -p "$rpm_dir"
  cp "$packages/$channel/"*.rpm "$rpm_dir/" 2>/dev/null || true
  if compgen -G "$rpm_dir/*.rpm" >/dev/null; then
    # Ubuntu's rpm calls gpg2, which its gnupg package does not install.
    rpmsign --addsign \
      --define "__gpg $(command -v gpg)" \
      --define "_gpg_name $key" \
      --define "_gpg_sign_cmd_extra_args --batch --pinentry-mode loopback --passphrase-file $passphrase" \
      "$rpm_dir/"*.rpm >/dev/null
  fi
  createrepo_c --quiet "$rpm_dir"
  "${gpg_batch[@]}" --armor --detach-sign --output "$rpm_dir/repodata/repomd.xml.asc" "$rpm_dir/repodata/repomd.xml"
  cat >"$site/rpm/contr-$channel.repo" <<REPO
[contr-$channel]
name=Contr ($channel)
baseurl=${SITE_URL:-https://contr-hq.github.io/contr-packages}/rpm/$channel
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=${SITE_URL:-https://contr-hq.github.io/contr-packages}/KEY.asc
REPO
done
