#!/bin/bash
# find_to_mdfind.sh - Wrapper to automatically convert 'find' commands to 'mdfind'
# This script can be sourced in .zshrc or .bashrc to make the conversion automatic

# Create a function for realfind to bypass and use original find
realfind() {
  command find "$@"
}

find_to_mdfind() {
  local args=("$@")
  local paths=()
  local name_pattern=""
  local iname_pattern=""
  local path_pattern=""
  local mtime=""
  local type=""
  local maxdepth=""
  local mindepth=""
  local size=""
  local negation=false
  local complex_query=false
  local exec_args=""
  
  # Check for bypass flags
  for arg in "${args[@]}"; do
    # Check if user wants to use real find with --real-find flag
    if [[ "$arg" == "--real-find" ]]; then
      echo "# Bypassing conversion, using original find command" >&2
      command find "${args[@]//--real-find/}"
      return
    fi
    
    # Check if user set environment variable to bypass
    if [[ -n "$USE_REAL_FIND" ]]; then
      echo "# USE_REAL_FIND environment variable set, using original find" >&2  
      command find "$@"
      return
    fi
  done
  
  # First detect complex queries that require special handling
  for ((i=0; i<${#args[@]}; i++)); do
    case "${args[$i]}" in
      \(|\)|-o|-a|-and|-or|-not)
        complex_query=true
        ;;
      -exec|-execdir)
        exec_args="${args[@]:$i}"
        break
        ;;
    esac
  done
  
  # Handle complex queries by falling back to find
  if [[ "$complex_query" == true ]]; then
    echo "# Complex query detected, using standard find" >&2
    command find "$@"
    return
  fi
  
  # Handle exec commands by falling back to find
  if [[ -n "$exec_args" ]]; then
    echo "# Exec command detected, using standard find" >&2
    command find "$@"
    return
  fi
  
  # Parse find arguments and convert to mdfind equivalents
  i=0
  while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
      # Path argument (non-option arguments are paths)
      [^-]*)
        if [ -d "${args[$i]}" ]; then
          paths+=("${args[$i]}")
        fi
        ;;
      # Name pattern (case sensitive)
      -name)
        i=$((i+1))
        name_pattern="${args[$i]}"
        ;;
      # Name pattern (case insensitive)
      -iname)
        i=$((i+1))
        iname_pattern="${args[$i]}"
        ;;
      # Path pattern
      -path|-wholepath)
        i=$((i+1))
        path_pattern="${args[$i]}"
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
      # Min depth
      -mindepth)
        i=$((i+1))
        mindepth="${args[$i]}"
        ;;
      # Size
      -size)
        i=$((i+1))
        size="${args[$i]}"
        ;;
      # Negation
      -not|!)
        negation=true
        ;;
      # Unsupported options - fall back to find
      -newer|-inum|-samefile|-links|-regex|-perm)
        echo "# Unsupported find option: ${args[$i]}, using standard find" >&2
        command find "$@"
        return
        ;;
    esac
    i=$((i+1))
  done
  
  # If no paths specified, use current directory
  if [ ${#paths[@]} -eq 0 ]; then
    paths=(".")
  fi
  
  # Process each path with mdfind
  for path in "${paths[@]}"; do
    local query=""
    
    # Handle name pattern (case sensitive)
    if [ -n "$name_pattern" ]; then
      # Strip quotes if present
      name_pattern="${name_pattern#\"}"
      name_pattern="${name_pattern%\"}"
      name_pattern="${name_pattern#\'}"
      name_pattern="${name_pattern%\'}"
      
      # Escape special characters for mdfind
      name_pattern="${name_pattern//\(/\\(}"
      name_pattern="${name_pattern//\)/\\)}"
      
      # Convert glob patterns to mdfind name search
      if [[ "$name_pattern" == *\** ]] || [[ "$name_pattern" == *\?* ]]; then
        query="kMDItemFSName = '$name_pattern'"
      else
        query="kMDItemDisplayName = '$name_pattern'"
      fi
    fi
    
    # Handle name pattern (case insensitive)
    if [ -n "$iname_pattern" ]; then
      # Strip quotes if present
      iname_pattern="${iname_pattern#\"}"
      iname_pattern="${iname_pattern%\"}"
      iname_pattern="${iname_pattern#\'}"
      iname_pattern="${iname_pattern%\'}"
      
      # Escape special characters for mdfind
      iname_pattern="${iname_pattern//\(/\\(}"
      iname_pattern="${iname_pattern//\)/\\)}"
      
      # Convert glob patterns to mdfind name search (case insensitive)
      if [[ -n "$query" ]]; then
        query="$query && kMDItemFSName =c '$iname_pattern'"
      else
        query="kMDItemFSName =c '$iname_pattern'"
      fi
    fi
    
    # Handle path pattern
    if [ -n "$path_pattern" ]; then
      # Strip quotes if present
      path_pattern="${path_pattern#\"}"
      path_pattern="${path_pattern%\"}"
      path_pattern="${path_pattern#\'}"
      path_pattern="${path_pattern%\'}"
      
      # Convert glob patterns to mdfind path search
      if [[ -n "$query" ]]; then
        query="$query && kMDItemPath = '$path_pattern'"
      else
        query="kMDItemPath = '$path_pattern'"
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
    
    # Handle modification time (enhanced conversion)
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
    
    # Handle size (simplified conversion)
    if [ -n "$size" ]; then
      if [[ "$size" == -* ]]; then
        # Less than specified size
        size_value="${size#-}"
        size_unit="${size_value: -1}"
        size_number="${size_value%?}"
        
        case "$size_unit" in
          k) multiplier=1024 ;;
          M) multiplier=1048576 ;;
          G) multiplier=1073741824 ;;
          *) multiplier=512 ;; # Default for no unit is 512-byte blocks
        esac
        
        size_bytes=$((size_number * multiplier))
        
        if [ -n "$query" ]; then
          query="$query && kMDItemFSSize < $size_bytes"
        else
          query="kMDItemFSSize < $size_bytes"
        fi
      else
        # Greater than specified size
        size_value="${size#+}"
        size_unit="${size_value: -1}"
        size_number="${size_value%?}"
        
        case "$size_unit" in
          k) multiplier=1024 ;;
          M) multiplier=1048576 ;;
          G) multiplier=1073741824 ;;
          *) multiplier=512 ;; # Default for no unit is 512-byte blocks
        esac
        
        size_bytes=$((size_number * multiplier))
        
        if [ -n "$query" ]; then
          query="$query && kMDItemFSSize > $size_bytes"
        else
          query="kMDItemFSSize > $size_bytes"
        fi
      fi
    fi
    
    # Handle negation
    if [[ "$negation" == true && -n "$query" ]]; then
      query="!($query)"
    fi
    
    # If no query was constructed, use a simple match-all query
    if [ -z "$query" ]; then
      query="kMDItemFSName = '*'"
    fi
    
    echo "# Converting 'find ${args[*]}' to mdfind" >&2
    echo "# Path: $path" >&2
    echo "# Query: mdfind -onlyin '$path' '$query'" >&2
    
    # Execute mdfind with the constructed query
    local results=$(mdfind -onlyin "$path" "$query")
    
    # Filter results by maxdepth if specified
    if [ -n "$maxdepth" ]; then
      # Convert the absolute path to a stripped version for depth calculation
      local base_path=$(echo "$path" | sed 's#/$##')
      local base_depth=$(echo "$base_path" | tr -cd '/' | wc -c)
      
      # Filter results by depth
      while IFS= read -r line; do
        local line_depth=$(echo "$line" | tr -cd '/' | wc -c)
        local rel_depth=$((line_depth - base_depth))
        
        if [ $rel_depth -le $maxdepth ]; then
          echo "$line"
        fi
      done <<< "$results"
    # Filter results by mindepth if specified
    elif [ -n "$mindepth" ]; then
      # Convert the absolute path to a stripped version for depth calculation
      local base_path=$(echo "$path" | sed 's#/$##')
      local base_depth=$(echo "$base_path" | tr -cd '/' | wc -c)
      
      # Filter results by depth
      while IFS= read -r line; do
        local line_depth=$(echo "$line" | tr -cd '/' | wc -c)
        local rel_depth=$((line_depth - base_depth))
        
        if [ $rel_depth -ge $mindepth ]; then
          echo "$line"
        fi
      done <<< "$results"
    else
      # No depth filtering
      echo "$results"
    fi
  done
}

# Function to alias 'find' to our converter
alias_find_to_mdfind() {
  # Create an alias for 'find' that calls our function
  alias find='find_to_mdfind'
  # No need to alias realfind as it's already a function
  echo "Converted 'find' to 'mdfind' for faster searching"
  echo "Use 'realfind' to access the original find command"
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
source "/Users/casey/CascadeProjects/Mdfind_override/src/find_to_mdfind.sh"
alias_find_to_mdfind

EOF
