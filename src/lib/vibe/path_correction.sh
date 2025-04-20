# FILE: src/lib/vibe/path_correction.sh
#!/usr/bin/env bash
# FlashFind Vibe Path Correction
set -o nounset; set -o pipefail; export LANG=C
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$DIR/../core/config.sh"; source "$DIR/../output/colors.sh"

common_replacements=(
  "s|/user/|/Users/|g" "s|slash user/|/Users/|g"
  "s|/documents/|/Documents/|g" "s|tilde/|~/|g" "s|home/|~/|g"
  "s| dash |-|g" "s| hyphen |-|g" "s| dot |.|g" "s| space | |g"
)

correct_path() {
  local orig="$1"; local corr="$orig"; local changed=false
  for rule in "${common_replacements[@]}"; do
    local tmp=$(echo "$corr" | sed -E "$rule")
    if [ "$tmp" != "$corr" ]; then corr="$tmp"; changed=true; fi
  done
  [[ "$corr" == ~* ]] && corr="${corr/#\~/$HOME}" && changed=true
  $changed && print_info "Path corrected: '$orig' → '$corr'"
  echo "$corr"
}

process_voice_path() { correct_path "$1"; }
