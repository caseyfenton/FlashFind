# FILE: src/lib/core/converter.sh
#!/usr/bin/env bash
# FlashFind Converter - find → mdfind
set -o nounset; set -o pipefail; export LANG=C
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$DIR/config.sh"; source "$DIR/../output/colors.sh"; source "$DIR/../core/history.sh"; source "$DIR/../vibe/path_correction.sh"

convert_to_mdfind() {
  local args=("$@"); local paths=() name="" iname="" pathp="" mtime="" type="" maxd="" mind="" size="" neg=false
  for arg in "${args[@]}"; do
    case "$arg" in
      -name) name="${args[++i]}"; save_to_history "${name//\"/}";;
      -iname) iname="${args[++i]}"; save_to_history "${iname//\"/}";;
      -path|-wholepath) pathp="${args[++i]}";;
      -type) type="${args[++i]}";;
      -mtime) mtime="${args[++i]}";;
      -maxdepth) maxd="${args[++i]}";;
      -mindepth) mind="${args[++i]}";;
      -size) size="${args[++i]}";;
      -not|!) neg=true;;
      -delete|-exec*|-ok|-print0|-fprintf|-printf|-ls|-fls|-perm|-user|-group|-uid|-regex)
        echo "# FlashFind: Using standard find for $arg" >&2; /usr/bin/find "${args[@]}"; return 1;;
      *) paths+=("$(correct_path "$arg")");;
    esac
  done
  [ ${#paths[@]} -eq 0 ] && paths=(".")
  local query=""
  [[ -n "$name" ]] && query="kMDItemFSName = '$name'"
  [[ -n "$iname" ]] && query="${query:+$query && }kMDItemFSName =c '$iname'"
  [[ -n "$pathp" ]] && query="${query:+$query && }kMDItemPath = '$pathp'"
  [[ "$type" == "f" ]] && query="${query:+$query && }kMDItemContentTypeTree = 'public.content'"
  [[ "$type" == "d" ]] && query="${query:+$query && }kMDItemContentTypeTree = 'public.folder'"
  if [[ -n "$mtime" ]]; then
    if [[ "$mtime" == -* ]]; then
      days="${mtime#-}"; query="${query:+$query && }kMDItemFSContentChangeDate > \$time.today(-$days)"
    else
      query="${query:+$query && }kMDItemFSContentChangeDate < \$time.today(-$mtime)"
    fi
  fi
  if [[ -n "$size" ]]; then
    sign=${size:0:1}; val=${size#[$sign]}; unit=${val: -1}; num=${val%?}
    case "$unit" in k) mul=1024;; M) mul=1048576;; G) mul=1073741824;; *) mul=512;; esac
    bytes=$(( num * mul ))
    if [[ "$sign" == "-" ]]; then op="<"; else op=">"; fi
    query="${query:+$query && }kMDItemFSSize $op $bytes"
  fi
  $neg && [[ -n "$query" ]] && query="!($query)"
  [ -z "$query" ] && query="kMDItemFSName = '*'"
  RESULTS_FILE=$(mktemp); for p in "${paths[@]}"; do mdfind -onlyin "$p" "$query" >> "$RESULTS_FILE"; done
  echo "$RESULTS_FILE"; return 0
}

