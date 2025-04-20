#!/bin/bash
# TurboFind - Lightning-fast file search tool that converts 'find' to 'mdfind'
# Overcomes the annoyingly slow find command by leveraging macOS Spotlight index

# Function for direct access to original find
realfind() {
  command find "$@"
}

# Main function to convert find to mdfind
turbofind() {
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
  if [[ " ${args[*]} " == *" --real-find "* ]]; then
    echo "# Bypassing conversion, using original find command" >&2
    realfind "${args[@]/--real-find/}"
    return
  fi
  
  # Check if environment variable is set to bypass
  if [[ -n "$USE_REAL_FIND" ]]; then
    echo "# USE_REAL_FIND environment variable set, using original find" >&2  
    realfind "$@"
    return
  fi
  
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
    realfind "$@"
    return
  fi
  
  # Handle exec commands by falling back to find
  if [[ -n "$exec_args" ]]; then
    echo "# Exec command detected, using standard find" >&2
    realfind "$@"
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
        realfind "$@"
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
    
    echo "# TurboFind: Converting find command to lightning-fast mdfind" >&2
    echo "# Path: $path" >&2
    echo "# Query: mdfind -onlyin '$path' '$query'" >&2
    
    # Record start time for performance comparison
    local start_time=$(date +%s.%N)
    
    # Execute mdfind with the constructed query
    local results=$(mdfind -onlyin "$path" "$query")
    
    # Record end time and calculate duration
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
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
    
    # Show performance stats
    echo "# TurboFind completed in ${duration}s" >&2
  done
}

# Function to set up TurboFind in your shell
setup_turbofind() {
  # Create an alias for 'find' that calls our function
  alias find='turbofind'
  echo "🚀 TurboFind: Converted 'find' to lightning-fast 'mdfind'"
  echo "💡 To use original find: 'realfind', 'find --real-find', or 'USE_REAL_FIND=1 find'"
}

# If this script is executed directly, show usage information
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "TurboFind - Lightning-fast replacement for the slow Unix find command"
  echo ""
  echo "Usage:"
  echo "  source $(basename "${BASH_SOURCE[0]}") && setup_turbofind"
  echo ""
  echo "This will replace the 'find' command with TurboFind in your current shell."
  echo "To make this permanent, add this to your ~/.bashrc or ~/.zshrc:"
  echo ""
  echo "  source /path/to/$(basename "${BASH_SOURCE[0]}")"
  echo "  setup_turbofind"
  echo ""
  echo "Use one of these methods to bypass TurboFind and use the original find:"
  echo "  - realfind /path -name '*.txt'         # Use the realfind command"
  echo "  - find --real-find /path -name '*.txt' # Use the --real-find flag"
  echo "  - USE_REAL_FIND=1 find /path -name '*.txt' # Set environment variable"
  exit 0
fi
