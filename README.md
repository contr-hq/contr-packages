# Contr packages

Signed APT and DNF repositories for [Contr](https://github.com/contr-hq/contr), served from GitHub Pages at
<https://contr-hq.github.io/contr-packages/>. The `publish` workflow rebuilds them from scratch, from the Linux packages
attached to every published release of [contr](https://github.com/contr-hq/contr) (`contr-daemon`) and
[contr-linux](https://github.com/contr-hq/contr-linux) (`contr`). It runs daily, on every push to `main`, when a release
workflow sends a `release` dispatch, and by hand.

| Channel | Holds |
|---|---|
| `stable` | Releases |
| `testing` | Releases and prereleases |

The same key signs every release's `SHA256SUMS`, published at `checksums/<repository>/<tag>/SHA256SUMS` and
`SHA256SUMS.asc`, so downloads from any Contr release can be checked against it.

## Install

Ubuntu and Debian:

```sh
sudo curl -fsSo /usr/share/keyrings/contr.gpg https://contr-hq.github.io/contr-packages/contr.gpg
echo "deb [signed-by=/usr/share/keyrings/contr.gpg] https://contr-hq.github.io/contr-packages/apt stable main" |
  sudo tee /etc/apt/sources.list.d/contr.list
sudo apt update && sudo apt install contr
```

Fedora:

```sh
sudo curl -fsSo /etc/yum.repos.d/contr-stable.repo https://contr-hq.github.io/contr-packages/rpm/contr-stable.repo
sudo dnf install contr
```

## How it is signed

- **APT:** `InRelease` and `Release.gpg` sign each channel's `Release`, which pins every `Packages` file by hash.
- **DNF:** every RPM carries a signature (`gpgcheck=1`), and `repomd.xml.asc` signs the metadata (`repo_gpgcheck=1`).
- **Checksums:** `SHA256SUMS.asc` signs each release's `SHA256SUMS`.
- **Key:** one GnuPG key signs all of these; [KEY.asc](https://contr-hq.github.io/contr-packages/KEY.asc) is its public
  half, fingerprint `B9475E35EE33A93291272EFB2EE1E61ADBE87687`. Only this repository's secrets hold the private key.

## Setting up the signing key

1. On a trusted machine, create an RSA 4096 signing key with a passphrase. Older RPM tools cannot verify Ed25519
   signatures, so RSA is the key type every supported distribution accepts.

   ```sh
   gpg --quick-generate-key "Contr packages <packages@example.org>" rsa4096 sign 3y
   gpg --armor --export-secret-keys <fingerprint> > contr-packages.key.asc
   ```

2. Add two repository secrets under Settings → Secrets and variables → Actions:

   | Secret | Value |
   |---|---|
   | `PACKAGES_SIGNING_KEY` | The whole of `contr-packages.key.asc` |
   | `PACKAGES_SIGNING_PASSPHRASE` | The key's passphrase |

3. Run the `publish` workflow. Until both secrets exist it publishes nothing and warns instead.

4. Optional: to publish as soon as a release is out, give the `contr` and `contr-linux` repositories a secret
   `PACKAGES_DISPATCH_TOKEN`, holding a fine-grained token with Contents read and write on this repository. Without it,
   new releases appear within a day.

Keep an offline copy of the key and a revocation certificate (`gpg --gen-revoke <fingerprint>`); losing the key means
every user has to trust a new one.

## Building locally

`scripts/collect.sh DIR` downloads the packages (it needs the GitHub CLI). `scripts/sign-checksums.sh SITE` signs every
release's checksums. `scripts/build-repos.sh DIR SITE` builds the signed repositories with the key whose fingerprint is `SIGNING_KEY` and whose passphrase is in the file
`SIGNING_PASSPHRASE_FILE`. It needs `apt-ftparchive`, `createrepo_c`, `rpmsign` and `gpg`.

Contributors follow [CLAUDE.md](CLAUDE.md) and the comment convention in [docs/COMMENTS.md](docs/COMMENTS.md).
