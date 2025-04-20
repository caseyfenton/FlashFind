#!/bin/bash
# FlashFind Core Module - Converter
# Handles conversion of find arguments to mdfind queries

# Import config if not already loaded
if [ -z "${FLASHFIND_VERSION}" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

# Load coloring utilities
source "$(dirname "${BASH_SOURCE[0]}")/../output/colors.sh"

# Import the history module for pattern tracking
source "$(dirname "${BASH_SOURCE[0]}")/../core/history.sh"

# Process arguments and convert to mdfind syntax
convert_to_mdfind() {
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
  
  # Debug output
  print_debug "Converting: ${args[*]}"
  
  # Look for operations that need the original find
  for arg in "${args[@]}"; do
    case "$arg" in
      # Complex operations that can't be easily converted to mdfind
      "-delete"|"-exec"|"-execdir"|"-ok"|"-print0"|"-fprintf"|"-printf"|"-ls"|"-fls")
        print_info "Using standard find for operation: $(print_yellow "$arg")"
        return 1
        ;;
    esac
  done
  
  # Parse find arguments and convert to mdfind equivalents
  local i=0
  while [ $i -lt ${#args[@]} ]; do
    local arg="${args[$i]}"
    print_debug "Processing arg[$i]: $arg"
    
    case "$arg" in
      # Path argument (non-option arguments are paths)
      [^-]*)
        # Make sure we're not looking at a value for a previous option
        if [[ $i -gt 0 && "${args[$i-1]}" =~ ^(-name|-iname|-path|-type|-mtime|-size|-maxdepth|-mindepth)$ ]]; then
          print_debug "Skipping $arg as a value for ${args[$i-1]}"
        else
          # Import the path correction module for handling voice paths
          source "$(dirname "${BASH_SOURCE[0]}")/../vibe/path_correction.sh"
          local corrected_path=$(process_voice_path "$arg")
          paths+=("$corrected_path")
          print_debug "Added path: $corrected_path"
        fi
        ;;
      # Name pattern (case sensitive)
      -name)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          name_pattern="${args[$i]}"
          # Remove quotes if present
          name_pattern="${name_pattern#\"}"
          name_pattern="${name_pattern%\"}"
          name_pattern="${name_pattern#\'}"
          name_pattern="${name_pattern%\'}"
          
          # Save pattern to history
          add_to_history "$name_pattern"
          print_debug "Name pattern: $name_pattern"
        fi
        ;;
      # Name pattern (case insensitive)
      -iname)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          iname_pattern="${args[$i]}"
          # Remove quotes if present
          iname_pattern="${iname_pattern#\"}"
          iname_pattern="${iname_pattern%\"}"
          iname_pattern="${iname_pattern#\'}"
          iname_pattern="${iname_pattern%\'}"
          
          # Save pattern to history
          add_to_history "$iname_pattern"
          print_debug "Iname pattern: $iname_pattern"
        fi
        ;;
      # Path pattern
      -path|-wholepath)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          path_pattern="${args[$i]}"
          # Remove quotes if present
          path_pattern="${path_pattern#\"}"
          path_pattern="${path_pattern%\"}"
          path_pattern="${path_pattern#\'}"
          path_pattern="${path_pattern%\'}"
          print_debug "Path pattern: $path_pattern"
        fi
        ;;
      # File type
      -type)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          type="${args[$i]}"
          print_debug "Type: $type"
        fi
        ;;
      # Modified time
      -mtime)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          mtime="${args[$i]}"
          print_debug "Mtime: $mtime"
        fi
        ;;
      # Max depth
      -maxdepth)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          maxdepth="${args[$i]}"
          print_debug "Maxdepth: $maxdepth"
        fi
        ;;
      # Min depth
      -mindepth)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          mindepth="${args[$i]}"
          print_debug "Mindepth: $mindepth"
        fi
        ;;
      # Size
      -size)
        i=$((i+1))
        if [ $i -lt ${#args[@]} ]; then
          size="${args[$i]}"
          print_debug "Size: $size"
        fi
        ;;
      # Negation
      -not|!)
        negation=true
        print_debug "Negation: true"
        ;;
      # Unsupported options - fall back to find
      -perm|-user|-group|-uid|-regex)
        print_info "Using standard find for unsupported option: $(print_yellow "$arg")"
        return 1
        ;;
    esac
    i=$((i+1))
  done
  
  # If no paths specified, use current directory
  if [ ${#paths[@]} -eq 0 ]; then
    paths=(".")
    print_debug "No paths specified, using current directory"
  fi
  
  # Results file (for processing results in a streaming fashion)
  local results_file=$(mktemp)
  
  # Record start time for performance comparison
  local start_time=$(date +%s.%N)
  
  # Process each path with mdfind
  for path in "${paths[@]}"; do
    local query=""
    
    # Handle name pattern (case sensitive)
    if [ -n "$name_pattern" ]; then
      # Escape special characters for mdfind
      local escaped_pattern="${name_pattern//\(/\\(}"
      escaped_pattern="${escaped_pattern//\)/\\)}"
      
      # Convert glob patterns to mdfind name search
      if [[ "$name_pattern" == *\** ]] || [[ "$name_pattern" == *\?* ]]; then
        query="kMDItemFSName = '$escaped_pattern'"
      else
        query="kMDItemDisplayName = '$escaped_pattern'"
      fi
    fi
    
    # Handle name pattern (case insensitive)
    if [ -n "$iname_pattern" ]; then
      # Convert glob patterns to mdfind name search (case insensitive)
      if [[ -n "$query" ]]; then
        query="$query && kMDItemFSName =c '$iname_pattern'"
      else
        query="kMDItemFSName =c '$iname_pattern'"
      fi
    fi
    
    # Handle path pattern
    if [ -n "$path_pattern" ]; then
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
        local days="${mtime#-}"
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
      local size_value=""
      local size_operator=""
      
      # Parse size operator and value
      if [[ "$size" == -* ]]; then
        size_operator="<"
        size_value="${size#-}"
      elif [[ "$size" == +* ]]; then
        size_operator=">"
        size_value="${size#+}"
      else
        size_operator="="
        size_value="$size"
      fi
      
      # Get unit and number
      local size_unit="${size_value: -1}"
      local size_number="${size_value%?}"
      local size_bytes=0
      
      # Calculate bytes based on unit
      case "$size_unit" in
        k) size_bytes=$((size_number * 1024)) ;;
        M) size_bytes=$((size_number * 1048576)) ;;
        G) size_bytes=$((size_number * 1073741824)) ;;
        *) size_bytes=$((size_number * 512)) ;; # Default is 512-byte blocks
      esac
      
      # Add to query
      if [ -n "$query" ]; then
        query="$query && kMDItemFSSize $size_operator $size_bytes"
      else
        query="kMDItemFSSize $size_operator $size_bytes"
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
    
    # Debug output before executing
    print_debug "mdfind command: mdfind -onlyin '$path' '$query'"
    
    # Execute mdfind with the constructed query
    mdfind -onlyin "$path" "$query" >> "$results_file"
    
    # Handle freshly created files that might not be indexed yet
    # If mdfind returns no results, try using regular find as a fallback
    if [ ! -s "$results_file" ]; then
      print_debug "No mdfind results, trying regular find as fallback for new files"
      # Construct a comparable find command for fresh files
      local find_cmd="/usr/bin/find '$path'"
      if [ -n "$name_pattern" ]; then
        find_cmd="$find_cmd -name '$name_pattern'"
      fi
      if [ -n "$type" ]; then
        find_cmd="$find_cmd -type $type"
      fi
      print_debug "Fallback find command: $find_cmd"
      # Execute find as fallback and append results
      eval $find_cmd >> "$results_file"
    fi
  done
  
  # Record end time and calculate duration
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc)
  
  # Filter results by maxdepth/mindepth if specified
  if [ -n "$maxdepth" ] || [ -n "$mindepth" ]; then
    print_debug "Filtering results by depth (max: $maxdepth, min: $mindepth)"
    local temp_file=$(mktemp)
    
    while IFS= read -r line; do
      if [ -z "$line" ]; then continue; fi
      
      # Get the path relative to the search path
      local rel_path=""
      for search_path in "${paths[@]}"; do
        if [[ "$line" == "$search_path"* ]]; then
          rel_path="${line#$search_path}"
          rel_path="${rel_path#/}"
          break
        fi
      done
      
      # Count directory levels
      local depth=$(echo "$rel_path" | tr -cd '/' | wc -c)
      
      # Apply maxdepth filter
      if [ -n "$maxdepth" ] && [ "$depth" -gt "$maxdepth" ]; then
        continue
      fi
      
      # Apply mindepth filter
      if [ -n "$mindepth" ] && [ "$depth" -lt "$mindepth" ]; then
        continue
      fi
      
      echo "$line" >> "$temp_file"
    done < "$results_file"
    
    # Replace results with filtered ones
    mv "$temp_file" "$results_file"
  fi
  
  # Show performance stats when debug is enabled
  print_debug "FlashFind completed in ${duration}s"
  if [ "${FLASHFIND_DEBUG}" -eq 1 ]; then
    local result_count=$(wc -l < "$results_file" | tr -d ' ')
    print_info "Found ${result_count} results in ${duration}s"
  fi
  
  # Return the results file path for processing by the caller
  echo "$results_file"
  return 0
}
