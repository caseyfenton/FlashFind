#!/bin/bash
# FlashFind Core - Lightning-fast replacement for find using mdfind
# Optimized for vibe coding (voice-to-text + LLM) interactions
# Version: 1.0.0

# Enable strict error handling
set -o nounset
set -o pipefail
export LANG=C

# Show usage information if no arguments
if [ $# -eq 0 ]; then
  echo "FlashFind - Lightning-fast replacement for the Unix find command"
  echo ""
  echo "Usage: ff [path] [options]"
  echo "  or:  find [path] [options] (if find replacement is enabled)"
  echo ""
  echo "FlashFind uses macOS Spotlight index (mdfind) for dramatically faster searches"
  echo "while maintaining find-compatible syntax."
  echo ""
  echo "Examples:"
  echo "  ff . -name \"*.txt\"                Find all .txt files in current directory"
  echo "  ff /Users -type d -name \"*backup*\"  Find directories with 'backup' in the name"
  echo "  ff ~/Documents -mtime -7           Find files modified in the last 7 days"
  echo ""
  echo "Vibe Coding Features (Voice + LLM):"
  echo "  ff . -name \"*.py\" --summary       Show summarized results with counts"
  echo "  ff . -name \"*.txt\" --content      Show file content previews"
  echo "  ff --vibe-mode                     Enable all vibe coding features"
  echo ""
  echo "For complex operations (like -exec), FlashFind automatically uses standard find"
  exit 0
fi

# Determine if this script is being called as 'find' or 'ff'
SCRIPT_NAME=$(basename "$0")

# Force use of standard find if specified environment variable
if [[ -n "${USE_STANDARD_FIND:-}" ]]; then
  /usr/bin/find "$@"
  exit $?
fi

# Create history dir if it doesn't exist
FLASHFIND_DIR="${HOME}/.flashfind"
HISTORY_FILE="${FLASHFIND_DIR}/history"
mkdir -p "${FLASHFIND_DIR}"
touch "${HISTORY_FILE}"

# Debug function - only prints if FLASHFIND_DEBUG is set
debug() {
  if [[ -n "${FLASHFIND_DEBUG:-}" ]]; then
    echo "# DEBUG: $*" >&2
  fi
}

# Check if mdfind is working and provide diagnostics
check_mdfind_health() {
  # Test basic mdfind functionality
  if ! mdfind -count -onlyin "$HOME" "kMDItemFSName = '*'" &>/dev/null; then
    echo "⚠️ mdfind appears to be having issues. Possible fixes:" >&2
    echo "  1. Spotlight indexing might be disabled" >&2
    echo "  2. Spotlight index might need rebuilding" >&2
    echo "" >&2
    echo "Try these commands to fix:" >&2
    echo "  sudo mdutil -i on /" >&2
    echo "  sudo mdutil -E /" >&2
    echo "" >&2
    echo "Running diagnostic check. This may take a moment..." >&2
    
    # Check if Spotlight is enabled
    if ! mdutil -s / | grep -q "Indexing enabled"; then
      echo "🔍 ISSUE DETECTED: Spotlight indexing is disabled" >&2
      echo "To fix, run: sudo mdutil -i on /" >&2
    fi
    
    # Check if Spotlight is actively indexing
    if mdutil -s / | grep -q "Indexing"; then
      echo "🔍 ISSUE DETECTED: Spotlight is currently indexing" >&2
      echo "Wait for indexing to finish or force with: sudo mdutil -E /" >&2
    fi
    
    # Check if path is in Spotlight's exclusion list
    if defaults read /.Spotlight-V100/VolumeConfiguration.plist Exclusions 2>/dev/null | grep -q "$PWD"; then
      echo "🔍 ISSUE DETECTED: Current directory is excluded from Spotlight" >&2
      echo "Check System Settings → Spotlight → Privacy" >&2
    fi
    
    echo "Falling back to standard find for reliability..." >&2
    return 1
  fi
  return 0
}

# Save search pattern to history
save_to_history() {
  local pattern="$1"
  
  # Don't save empty patterns
  if [ -z "$pattern" ]; then
    return
  fi
  
  # Check if pattern already exists to avoid duplicates
  if ! grep -q "^$pattern$" "$HISTORY_FILE" 2>/dev/null; then
    # Add to beginning of file (more recent patterns first)
    echo "$pattern" | cat - "$HISTORY_FILE" > /tmp/flashfind_history && mv /tmp/flashfind_history "$HISTORY_FILE"
    # Keep only last 20 patterns
    head -20 "$HISTORY_FILE" > /tmp/flashfind_history && mv /tmp/flashfind_history "$HISTORY_FILE"
  fi
}

# Auto-correct common voice dictation path errors
correct_path() {
  local original_path="$1"
  local corrected_path="$original_path"
  
  # Common voice dictation path corrections
  if [[ "$corrected_path" == "/user/"* ]]; then
    corrected_path="${corrected_path/\/user\//\/Users\/}"
    echo "# FlashFind: Corrected path from '$original_path' to '$corrected_path'" >&2
  fi
  
  if [[ "$corrected_path" == "slash user/"* ]]; then
    corrected_path="${corrected_path/slash user\//\/Users\/}"
    echo "# FlashFind: Corrected path from '$original_path' to '$corrected_path'" >&2
  fi
  
  if [[ "$corrected_path" == "tilde/"* ]]; then
    corrected_path="${corrected_path/tilde\//~\/}"
    echo "# FlashFind: Corrected path from '$original_path' to '$corrected_path'" >&2
  fi
  
  if [[ "$corrected_path" == "home/"* ]]; then
    corrected_path="${corrected_path/home\//~\/}"
    echo "# FlashFind: Corrected path from '$original_path' to '$corrected_path'" >&2
  fi
  
  # Expand ~ if present
  corrected_path="${corrected_path/#\~/$HOME}"
  
  echo "$corrected_path"
}

# Format summarized results for voice interaction
format_summary_results() {
  local results="$1"
  local count=0
  
  # Count non-empty lines
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      ((count++))
    fi
  done <<< "$results"
  
  if [ "$count" -eq 0 ]; then
    echo "No matching files found."
    return
  fi
  
  echo "Found $count matching files."
  
  if [ "$count" -le 5 ]; then
    echo "Files:"
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then
        echo "  - $line"
      fi
    done <<< "$results"
  else
    echo "Examples:"
    local examples=0
    while IFS= read -r line; do
      if [[ -n "$line" && "$examples" -lt 3 ]]; then
        echo "  - $line"
        ((examples++))
      fi
    done <<< "$results"
    echo "  ... and $(($count - 3)) more files"
  fi
}

# Show content preview for text files
show_content_preview() {
  local results="$1"
  local preview_count=0
  local max_previews=5
  
  while IFS= read -r file; do
    # Skip empty lines
    if [[ -z "$file" ]]; then
      continue
    fi
    
    # Skip if we've shown max previews
    if [ "$preview_count" -ge "$max_previews" ]; then
      local remaining=0
      while IFS= read -r remaining_file; do
        if [[ -n "$remaining_file" ]]; then
          ((remaining++))
        fi
      done <<< "$results"
      if [[ "$remaining" -gt 0 ]]; then
        echo "... and $remaining more files (use --preview-all to show all)"
      fi
      break
    fi
    
    # Only preview text files
    if [[ -f "$file" ]] && file "$file" | grep -q text; then
      echo "=== $file ==="
      head -5 "$file" 2>/dev/null
      echo "..."
      echo ""
      preview_count=$((preview_count + 1))
    fi
  done <<< "$results"
}

# Check mdfind health before using it
if ! check_mdfind_health; then
  /usr/bin/find "$@"
  exit $?
fi

# Suggest from history if no pattern is provided
suggest_from_history() {
  if [ -f "$HISTORY_FILE" ]; then
    echo "# FlashFind: Recent search patterns:" >&2
    tail -3 "$HISTORY_FILE" | sed 's/^/#  /' >&2
  fi
}

# Process and convert find arguments to mdfind query
process_find_args() {
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
  
  # Check for vibe coding flags
  local vibe_mode=false
  local summary_mode=false
  local content_mode=false
  
  # Process vibe coding flags first and remove them from args
  local new_args=()
  for arg in "${args[@]}"; do
    if [[ "$arg" == "--vibe-mode" ]]; then
      vibe_mode=true
      echo "# FlashFind: Vibe coding mode enabled" >&2
    elif [[ "$arg" == "--summary" ]]; then
      summary_mode=true
    elif [[ "$arg" == "--content" ]]; then
      content_mode=true
    else
      new_args+=("$arg")
    fi
  done
  
  # Replace args with filtered list
  args=("${new_args[@]}")
  
  # If vibe mode is on, enable all features
  if [ "$vibe_mode" = true ]; then
    summary_mode=true
    content_mode=true
  fi
  
  # First pass: Check for advanced args that need original find
  for arg in "${args[@]}"; do
    case "$arg" in
      # These operations can't be done with mdfind - use standard find
      "-delete"|"-exec"|"-execdir"|"-ok"|"-print0"|"-fprintf"|"-printf"|"-ls"|"-fls")
        echo "# FlashFind: Using standard find for operation: $arg" >&2
        /usr/bin/find "$@"
        return 1
        ;;
    esac
  done
  
  # Parse find arguments
  local i=0
  while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
      # Path argument (non-option arguments are paths)
      [^-]*)
        # Skip if this is a value for a previous option
        if [[ $i -gt 0 && ( "${args[$i-1]}" == "-name" || "${args[$i-1]}" == "-iname" || "${args[$i-1]}" == "-path" || "${args[$i-1]}" == "-type" || "${args[$i-1]}" == "-mtime" || "${args[$i-1]}" == "-size" ) ]]; then
          # This is a value, not a path
          debug "Skipping ${args[$i]} as it's a value for ${args[$i-1]}"
        else
          local check_path="${args[$i]}"
          # Apply path correction for vibe coding
          local corrected_path=$(correct_path "$check_path")
          
          # Check if path exists or is a glob pattern
          if [ -e "$corrected_path" ] || [[ "$corrected_path" == *"*"* ]]; then
            paths+=("$corrected_path")
            debug "Added path: $corrected_path"
          else
            debug "Path doesn't exist: $corrected_path"
          fi
        fi
        ;;
      # Name pattern (case sensitive)
      -name)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          name_pattern="${args[$i]}"
          # Save pattern to history
          save_to_history "${name_pattern//\"/}"
        fi
        ;;
      # Name pattern (case insensitive)
      -iname)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          iname_pattern="${args[$i]}"
          # Save pattern to history
          save_to_history "${iname_pattern//\"/}"
        fi
        ;;
      # Path pattern
      -path|-wholepath)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          path_pattern="${args[$i]}"
        fi
        ;;
      # File type
      -type)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          type="${args[$i]}"
        fi
        ;;
      # Modified time
      -mtime)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          mtime="${args[$i]}"
        fi
        ;;
      # Max depth
      -maxdepth)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          maxdepth="${args[$i]}"
        fi
        ;;
      # Min depth
      -mindepth)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          mindepth="${args[$i]}"
        fi
        ;;
      # Size
      -size)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          size="${args[$i]}"
        fi
        ;;
      # Negation
      -not|!)
        negation=true
        ;;
      # Unsupported options - fall back to find
      -perm|-user|-group|-uid|-regex)
        echo "# FlashFind: Using standard find for unsupported option: ${args[$i]}" >&2
        /usr/bin/find "$@"
        return 1
        ;;
    esac
    i=$((i+1))
  done
  
  # If no paths specified, use current directory
  if [ ${#paths[@]} -eq 0 ]; then
    paths=(".")
    debug "No paths specified, using current directory"
  fi
  
  # Convert find args to mdfind query and execute search
  execute_mdfind_search "$name_pattern" "$iname_pattern" "$path_pattern" "$type" "$mtime" "$size" "$negation" "$maxdepth" "$mindepth" "${paths[@]}"
  
  # Format the results according to vibe mode
  local result_code=$?
  if [ $result_code -eq 0 ]; then
    # Format results based on mode flags
    if [ "$summary_mode" = true ]; then
      format_summary_results "$(cat /tmp/flashfind_results.$$)"
      rm -f "/tmp/flashfind_results.$$"
    elif [ "$content_mode" = true ]; then
      show_content_preview "$(cat /tmp/flashfind_results.$$)"
      rm -f "/tmp/flashfind_results.$$"
    else
      cat "/tmp/flashfind_results.$$"
      rm -f "/tmp/flashfind_results.$$"
    fi
  fi
  
  return $result_code
}

# Execute mdfind search with the prepared query
execute_mdfind_search() {
  local name_pattern="$1"
  local iname_pattern="$2"
  local path_pattern="$3"
  local type="$4"
  local mtime="$5"
  local size="$6"
  local negation="$7"
  local maxdepth="$8"
  local mindepth="$9"
  shift 9
  local paths=("$@")
  
  # Record start time for performance comparison
  local start_time=$(date +%s.%N)
  
  # Process each path with mdfind
  rm -f "/tmp/flashfind_results.$$"
  touch "/tmp/flashfind_results.$$"
  
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
    
    # Debug output
    debug "Path: $path"
    debug "Query: mdfind -onlyin '$path' '$query'"
    
    # Execute mdfind with the constructed query
    mdfind -onlyin "$path" "$query" >> "/tmp/flashfind_results.$$"
    
    # Filter results by maxdepth/mindepth if specified
    if [ -n "$maxdepth" ] || [ -n "$mindepth" ]; then
      debug "Filtering by depth (max: $maxdepth, min: $mindepth)"
      # Process depth filtering in a separate step
      local filtered_results=$(mktemp)
      local base_path=$(echo "$path" | sed 's#/$##')
      local base_depth=$(echo "$base_path" | tr -cd '/' | wc -c)
      
      while IFS= read -r line; do
        if [[ -z "$line" ]]; then continue; fi
        
        local line_depth=$(echo "$line" | tr -cd '/' | wc -c)
        local rel_depth=$((line_depth - base_depth))
        
        # Apply maxdepth filter
        if [[ -n "$maxdepth" && $rel_depth -gt $maxdepth ]]; then
          continue
        fi
        
        # Apply mindepth filter
        if [[ -n "$mindepth" && $rel_depth -lt $mindepth ]]; then
          continue
        fi
        
        echo "$line" >> "$filtered_results"
      done < "/tmp/flashfind_results.$$"
      
      # Replace results with filtered ones
      mv "$filtered_results" "/tmp/flashfind_results.$$"
    fi
  done
  
  # Record end time and calculate duration
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
  
  # Show performance stats when debug is enabled
  debug "FlashFind completed in ${duration}s"
  
  return 0
}

# Main function
main() {
  # Suggest from history if relevant
  if [[ "$*" == *"-name"* && "$*" != *"-name "*\"* ]]; then
    suggest_from_history
  fi
  
  # Process and convert find arguments to mdfind
  process_find_args "$@"
  return $?
}

# Run the main function with all arguments
main "$@"
