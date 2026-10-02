#!/usr/bin/env bash
# Check that internal references in this repo's Markdown point to real files.
# Checks Markdown links [text](path) and backtick paths that start with a
# top-level folder of this repo (router/, rules/, enforcement/ ...).
# Paths inside other projects (.ai/..., <project>/...) are not checked, and
# neither are backtick paths in plans/ (plans name files that do not exist yet).
# Usage: bash scripts/check-links.sh [repo-dir]    Exit 1 on a broken link.
cd "${1:-$(dirname "$0")/..}" || exit 1
tops=$(git ls-files | cut -d/ -f1 | sort -u | grep -v '\.' | paste -sd'|')
broken=0
while IFS= read -r md; do
  dir=$(dirname "$md")
  # [text](target) -> target, without #anchor; skip URLs and pure anchors.
  links=$(grep -oE '\]\([^)[:space:]]+\)' "$md" | sed -E 's/^\]\(//; s/\)$//; s/#.*//' | grep -vE '^(https?:|mailto:|$)')
  # `top/dir/file.ext` references to this repo.
  # Plans describe files that do not exist yet, so their backtick paths are skipped.
  refs=""
  case "$md" in plans/*) ;; *)
    refs=$(grep -oE "\`($tops)/[A-Za-z0-9_./-]+\`" "$md" | tr -d '`' | grep -vE '[*<>]') ;;
  esac
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    [ -e "$dir/$l" ] || [ -e "$l" ] || { echo "$md: broken link ($l)"; broken=1; }
  done <<<"$links"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    [ -e "$dir/${r%/}" ] || [ -e "${r%/}" ] || { echo "$md: missing path \`$r\`"; broken=1; }
  done <<<"$refs"
done < <(git ls-files '*.md')
[ $broken = 0 ] && echo "All internal links resolve." || exit 1
