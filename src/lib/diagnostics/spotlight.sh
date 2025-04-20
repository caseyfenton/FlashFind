# FILE: src/lib/diagnostics/spotlight.sh
#!/usr/bin/env bash
# FlashFind Spotlight Diagnostics
set -o nounset; set -o pipefail; export LANG=C
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$DIR/../core/config.sh"; source "$DIR/../output/colors.sh"

check_mdfind_health() {
  if ! timeout 5 mdfind -count -onlyin "$HOME" "kMDItemFSName = '*'" &>/dev/null; then
    print_warning "mdfind appears to be having issues. Falling back to find."
    return 1
  fi
  return 0
}

benchmark_mdfind() {
  local path="${1:-$HOME}"; local qry="${2:-*}"
  print_info "Benchmarking mdfind vs find in $path for $qry"
  local mstart=$(date +%s.%N); mcount=$(mdfind -onlyin "$path" "kMDItemFSName = '$qry'" | wc -l); mend=$(date +%s.%N)
  local fstart=$(date +%s.%N); fcount=$(find "$path" -name "$qry" 2>/dev/null | wc -l); fend=$(date +%s.%N)
  echo "mdfind: $((mend - mstart))s, $mcount files"; echo "find:   $((fend - fstart))s, $fcount files"
}

get_spotlight_status() {
  print_info "Spotlight status report saved."
  mdutil -s /
}

