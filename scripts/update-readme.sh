#!/usr/bin/env bash
# Regenerate the project table between the REPOS markers in profile/README.md
# from the org's public repos. Private repos are never requested.
set -euo pipefail

ORG="${ORG:-game-design-projects}"
README="${1:-profile/README.md}"

auth=()
[ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

raw="$(mktemp)"; table="$(mktemp)"; out="$(mktemp)"
trap 'rm -f "$raw" "$table" "$out"' EXIT

curl -fsS ${auth[@]+"${auth[@]}"} -H "Accept: application/vnd.github+json" \
  "https://api.github.com/orgs/${ORG}/repos?type=public&per_page=100&sort=pushed" > "$raw"

jq -r --arg org "$ORG" '
  [ .[] | select(.private == false and .archived == false and .fork == false)
        | select(.name != ".github" and .name != ($org + ".github.io")) ]
  | sort_by(.pushed_at) | reverse
  | ( "| Project | About | Play | Updated |", "| --- | --- | --- | --- |" ),
    ( .[] | "| [\(.name)](\(.html_url)) | \((.description // "") | gsub("\\|"; "\\|")) | \(if (.homepage // "") != "" then "[▶ Play](\(.homepage))" else "" end) | \(.pushed_at[0:10]) |" )
' "$raw" > "$table"

awk -v tf="$table" '
  /<!-- REPOS:START -->/ { print; while ((getline l < tf) > 0) print l; skip=1; next }
  /<!-- REPOS:END -->/   { skip=0 }
  !skip { print }
' "$README" > "$out"

cp "$out" "$README"
echo "[update-readme] $(($(wc -l < "$table") - 2)) repos listed"
