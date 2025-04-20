#!/bin/bash
# FlashFind Fuzzy Module - Path Finding
# Handles fuzzy matching for paths with incorrect capitalization or punctuation

# Import config if not already loaded
if [ -z "${FLASHFIND_VERSION}" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"
fi

# Load coloring utilities
source "$(dirname "${BASH_SOURCE[0]}")/../output/colors.sh"

# Normalize a string for fuzzy matching (lowercase, remove punctuation)
normalize_string() {
  local str="$1"
  # Convert to lowercase and remove non-alphanumeric characters
  echo "$str" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g'
}

# Calculate Levenshtein distance between two strings
# This is a simplified implementation - for production, consider a faster algorithm
levenshtein_distance() {
  local str1="$1"
  local str2="$2"
  
  # Fast path - if strings are identical
  if [ "$str1" = "$str2" ]; then
    echo "0"
    return
  fi
  
  # Fast path - if one string is empty
  if [ -z "$str1" ]; then
    echo "${#str2}"
    return
  fi
  if [ -z "$str2" ]; then
    echo "${#str1}"
    return
  fi
  
  # For truly accurate Levenshtein we'd need a complex implementation
  # This is a simplified version that uses normalized edit distance
  # For production code, consider using a Python helper or a more optimized approach
  
  # Normalize both strings
  local norm1=$(normalize_string "$str1")
  local norm2=$(normalize_string "$str2")
  
  # Use macOS's built-in diff to get a rough estimate of the differences
  local diff_count=$(diff -y --suppress-common-lines <(echo "$norm1" | fold -w1) <(echo "$norm2" | fold -w1) | wc -l)
  
  echo "$diff_count"
}

# Find closest matching path for a given path
# Uses fuzzy matching to handle capitalization and punctuation issues
find_closest_path() {
  local target_path="$1"
  local best_match="$target_path"
  local min_distance=999999
  local threshold=3  # Maximum edit distance to consider a match
  
  # Split path into directory and filename/pattern
  local dir_part=$(dirname "$target_path")
  local file_part=$(basename "$target_path")
  
  # If directory doesn't exist, try to find closest match
  if [ ! -d "$dir_part" ] && [ "$dir_part" != "." ]; then
    # Try to find parent directories that exist
    local parent_dir="$dir_part"
    while [ ! -d "$parent_dir" ] && [ "$parent_dir" != "/" ] && [ "$parent_dir" != "." ]; do
      parent_dir=$(dirname "$parent_dir")
    done
    
    # If we found a valid parent directory, look for subdirectories that might match
    if [ -d "$parent_dir" ]; then
      local target_subdir=$(basename "$dir_part")
      local normalized_target=$(normalize_string "$target_subdir")
      
      # Use find to get all subdirectories
      while IFS= read -r subdir; do
        if [ -z "$subdir" ]; then continue; fi
        
        local subdir_name=$(basename "$subdir")
        local normalized_subdir=$(normalize_string "$subdir_name")
        local distance=$(levenshtein_distance "$normalized_target" "$normalized_subdir")
        
        if [ "$distance" -lt "$min_distance" ] && [ "$distance" -le "$threshold" ]; then
          min_distance="$distance"
          best_match="${parent_dir}/${subdir_name}/${file_part}"
          
          # If it's an exact match, we're done
          if [ "$distance" -eq 0 ]; then
            break
          fi
        fi
      done < <(find "$parent_dir" -maxdepth 1 -type d 2>/dev/null)
    fi
  fi
  
  # If the directory exists but the file doesn't, try fuzzy matching filenames
  if [ -d "$dir_part" ] && [[ "$file_part" != *"*"* ]] && [ ! -e "${dir_part}/${file_part}" ]; then
    local normalized_target=$(normalize_string "$file_part")
    min_distance=999999
    
    # Use find to get all files in the directory
    while IFS= read -r file; do
      if [ -z "$file" ]; then continue; fi
      
      local file_name=$(basename "$file")
      local normalized_file=$(normalize_string "$file_name")
      local distance=$(levenshtein_distance "$normalized_target" "$normalized_file")
      
      if [ "$distance" -lt "$min_distance" ] && [ "$distance" -le "$threshold" ]; then
        min_distance="$distance"
        best_match="${dir_part}/${file_name}"
        
        # If it's an exact match, we're done
        if [ "$distance" -eq 0 ]; then
          break
        fi
      fi
    done < <(find "$dir_part" -maxdepth 1 -type f 2>/dev/null)
  fi
  
  # If the best match is different from the original, notify user
  if [ "$best_match" != "$target_path" ]; then
    if [ "${FLASHFIND_USE_COLOR}" -eq 1 ]; then
      print_info "Fuzzy matched: '$(print_yellow "$target_path")' → '$(print_green "$best_match")' (distance: $min_distance)"
    else
      echo "# FlashFind: Fuzzy matched: '$target_path' → '$best_match' (distance: $min_distance)" >&2
    fi
  fi
  
  echo "$best_match"
}

# Check if a string has incorrect capitalization based on existing files
# Returns the correctly capitalized version if found
fix_capitalization() {
  local path="$1"
  local dir_part=$(dirname "$path")
  local file_part=$(basename "$path")
  
  # Skip if using glob patterns
  if [[ "$file_part" == *"*"* ]]; then
    echo "$path"
    return
  fi
  
  # Check if directory exists
  if [ ! -d "$dir_part" ]; then
    echo "$path"
    return
  fi
  
  # Look for files with same name but different capitalization
  local correct_case=$(find "$dir_part" -maxdepth 1 -name "$file_part" -o -iname "$file_part" | head -n 1)
  
  if [ -n "$correct_case" ]; then
    if [ "$correct_case" != "$path" ]; then
      if [ "${FLASHFIND_USE_COLOR}" -eq 1 ]; then
        print_info "Fixed capitalization: '$(print_yellow "$path")' → '$(print_green "$correct_case")'"
      else
        echo "# FlashFind: Fixed capitalization: '$path' → '$correct_case'" >&2
      fi
    fi
    echo "$correct_case"
  else
    echo "$path"
  fi
}
