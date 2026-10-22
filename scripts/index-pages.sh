#!/usr/bin/env bash
# Writes an index.html listing the entries of every directory under $1 except the site's root, which has its own page,
# since GitHub Pages answers a directory URL without one with 404.
set -euo pipefail

site=${1:?usage: index-pages.sh SITE}

find "$site" -mindepth 1 -type d | sort | while read -r dir; do
  relative=${dir#"$site"/}
  depth=$(($(tr -cd / <<<"$relative" | wc -c) + 1))
  home=$(printf '../%.0s' $(seq "$depth"))
  {
    cat <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Contr packages: $relative</title>
<style>
  :root { color-scheme: light dark; }
  body { margin: 0 auto; max-width: 46rem; padding: 2rem 1rem; font: 16px/1.6 system-ui, sans-serif; }
  li { font-family: ui-monospace, monospace; }
</style>
</head>
<body>
<p><a href="$home">Contr packages</a> / $relative/</p>
<ul>
<li><a href="../">../</a></li>
HTML
    find "$dir" -mindepth 1 -maxdepth 1 ! -name index.html -printf '%y %f\n' | sort -k2 |
      while read -r kind name; do
        [[ "$kind" == d ]] && name="$name/"
        echo "<li><a href=\"$name\">$name</a></li>"
      done
    [[ -n "$(find "$dir" -mindepth 1 -maxdepth 1 ! -name index.html -print -quit)" ]] || echo "<li>(empty)</li>"
    cat <<HTML
</ul>
</body>
</html>
HTML
  } >"$dir/index.html"
done
