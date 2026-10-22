# Contr packages: working rules

- This repository builds and publishes the signed APT and DNF repositories; it holds no product code.
- The private signing key lives only in the `PACKAGES_SIGNING_KEY` secret. Never print it, commit it or pass it to a
  step that does not sign.
- Scripts are Bash with `set -euo pipefail` and pass `shellcheck`.
- Comments follow [docs/COMMENTS.md](docs/COMMENTS.md): facts the code cannot show, no narrative, no history.
- Conventional Commits; `main` changes land through pull requests with green CI.
