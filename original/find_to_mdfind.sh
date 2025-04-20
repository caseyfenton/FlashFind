#!/bin/bash
# find_to_mdfind.sh - Wrapper to automatically convert 'find' commands to 'mdfind'
# This script can be sourced in .zshrc or .bashrc to make the conversion automatic

find_to_mdfind() {
  local args=("$@")
  local path="."
  local name_pattern=""
  local mtime=""
  local type=""
  local maxdepth=""
  
  # Parse find arguments and convert to mdfind equivalents
  i=0
  while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
      # Path argument (first non-option argument)
      [^-]*)
        if [ -d "${args[$i]}" ]; then
          path="${args[$i]}"
        fi
        ;;
      # Name pattern
      -name)
        i=$((i+1))
        name_pattern="${args[$i]}"
        # Convert glob pattern to regex
        name_pattern="${name_pattern//\*/.*}"
        name_pattern="${name_pattern//\?/.}"
        ;;
      # File type
      -type)
        i=$((i+1))
        type="${args[$i]}"
        ;;
      # Modified time
      -mtime)
        i=$((i+1))
        mtime="${args[$i]}"
        ;;
      # Max depth
      -maxdepth)
        i=$((i+1))
        maxdepth="${args[$i]}"
        ;;
    esac
    i=$((i+1))
  done
  
  # Build mdfind query
  local query=""
  
  # Handle name pattern
  if [ -n "$name_pattern" ]; then
    # Strip quotes if present
    name_pattern="${name_pattern#\"}"
    name_pattern="${name_pattern%\"}"
    name_pattern="${name_pattern#\'}"
    name_pattern="${name_pattern%\'}"
    
    # Convert simple glob patterns to mdfind name search
    if [[ "$name_pattern" == \** ]] || [[ "$name_pattern" == *\* ]]; then
      query="kMDItemFSName = '$name_pattern'"
    else
      query="kMDItemDisplayName = '$name_pattern'"
    fi
  fi
  
  # Handle file type
  if [ "$type" = "f" ]; then
    if [ -n "$query" ]; then
      query="$query && kMDItemContentTypeTree = 'public.content'"
    else
      query="kMDItemContentTypeTree = 'public.content'"
    fi
  elif [ "$type" = "d" ]; then
    if [ -n "$query" ]; then
      query="$query && kMDItemContentTypeTree = 'public.folder'"
    else
      query="kMDItemContentTypeTree = 'public.folder'"
    fi
  fi
  
  # Handle modification time (very simplified conversion)
  if [ -n "$mtime" ]; then
    # Handle negative mtime (files modified less than N days ago)
    if [[ "$mtime" == -* ]]; then
      days="${mtime#-}"
      if [ -n "$query" ]; then
        query="$query && kMDItemFSContentChangeDate > \$time.today(-$days)"
      else
        query="kMDItemFSContentChangeDate > \$time.today(-$days)"
      fi
    # Handle positive mtime (files modified more than N days ago)
    else
      if [ -n "$query" ]; then
        query="$query && kMDItemFSContentChangeDate < \$time.today(-$mtime)"
      else
        query="kMDItemFSContentChangeDate < \$time.today(-$mtime)"
      fi
    fi
  fi
  
  # If no query was constructed, use a simple match-all query
  if [ -z "$query" ]; then
    query="kMDItemFSName = '*'"
  fi
  
  echo "# Converting 'find ${args[*]}' to mdfind" >&2
  echo "# Query: mdfind -onlyin '$path' '$query'" >&2
  
  # Execute mdfind with the constructed query
  mdfind -onlyin "$path" "$query"
}

# Function to alias 'find' to our converter
alias_find_to_mdfind() {
  # Create an alias for 'find' that calls our function
  alias find='find_to_mdfind'
  echo "Converted 'find' to 'mdfind' for faster searching"
}

# Instructions for installation
cat << EOF
=== find_to_mdfind installation ===

To permanently replace 'find' with 'mdfind' system-wide, add these lines to your ~/.zshrc or ~/.bashrc:

source "$PWD/find_to_mdfind.sh"
alias_find_to_mdfind

For temporary usage in the current shell only:
source "$PWD/find_to_mdfind.sh"
alias_find_to_mdfind

For a single script, add this line at the beginning:
source "/Users/casey/CascadeProjects/Tmobile/scripts/find_to_mdfind.sh"
alias_find_to_mdfind

EOF
