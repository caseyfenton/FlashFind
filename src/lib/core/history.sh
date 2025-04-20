# FILE: src/lib/core/history.sh
#!/usr/bin/env bash
# FlashFind History
set -o nounset; set -o pipefail; export LANG=C
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$DIR/config.sh"; source "$DIR/../output/colors.sh"

add_to_history() {
  local pat="$1"
  [ -z "$pat" ] && return
  grep -qxF "$pat" "$HISTORY_FILE" 2>/dev/null || {
    echo "$pat" | cat - "$HISTORY_FILE" > /tmp/flashfind_history && mv /tmp/flashfind_history "$HISTORY_FILE"
    head -n "$FLASHFIND_MAX_HISTORY" "$HISTORY_FILE" > /tmp/flashfind_history && mv /tmp/flashfind_history "$HISTORY_FILE"
  }
}

get_frequent_patterns() {
  local n="${1:-5}"
  sort "$HISTORY_FILE" | uniq -c | sort -rn | head -n "$n" | while read -r cnt pat; do
    echo "  $(print_cyan •) $(print_gray "$pat") (${cnt}×)" >&2
  done
}

suggest_from_history() {
  if [ -s "$HISTORY_FILE" ]; then
    print_info "Recent search patterns:"
    head -n 3 "$HISTORY_FILE" | while read -r pat; do
      echo "  $(print_cyan •) $(print_gray "$pat")" >&2
    done
  fi
}

clear_history() { : > "$HISTORY_FILE"; print_success "Search history cleared"; }

