# FILE: src/lib/fuzzy/finder.sh
#!/usr/bin/env bash
# FlashFind Fuzzy Finder
set -o nounset; set -o pipefail; export LANG=C
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$DIR/../core/config.sh"; source "$DIR/../output/colors.sh"

normalize_string() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g'; }

levenshtein_distance() {
  local s1=$(normalize_string "$1"); local s2=$(normalize_string "$2")
  if [ "$s1" == "$s2" ]; then echo 0; return; fi
  diff -y --suppress-common-lines <(echo "$s1" | fold -w1) <(echo "$s2" | fold -w1) | wc -l
}

find_closest_path() {
  local target="$1"; local dir=$(dirname "$target"); local base=$(basename "$target")
  local best="$target"; local min=999; local dist
  if [ ! -d "$dir" ]; then echo "$target"; return; fi
  while read -r entry; do
    dist=$(levenshtein_distance "$base" "$(basename "$entry")")
    if [ $dist -lt $min ]; then min=$dist; best="$entry"; fi
  done < <(find "$dir" -maxdepth 1 -type f 2>/dev/null)
  if [ "$best" != "$target" ]; then print_info "Fuzzy matched: '$target' → '$best' (distance: $min)"; fi
  echo "$best"
}

