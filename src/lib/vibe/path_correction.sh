#!/bin/bash
# FlashFind Vibe Module - Path Correction
# Handles corrections for common voice-to-text path issues

# Import config if not already loaded
if [ -z "${FLASHFIND_VERSION}" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"
fi

# Load coloring utilities
source "$(dirname "${BASH_SOURCE[0]}")/../output/colors.sh"

# Common path transforms for voice dictation errors
common_path_replacements=(
  # Common capitalization errors
  "s|/user/|/Users/|g"
  "s|/documents/|/Documents/|g"
  "s|/desktop/|/Desktop/|g"
  "s|/downloads/|/Downloads/|g"
  "s|/applications/|/Applications/|g"
  "s|/library/|/Library/|g"
  "s|/music/|/Music/|g"
  "s|/pictures/|/Pictures/|g"
  "s|/movies/|/Movies/|g"
  "s|/public/|/Public/|g"
  
  # Common voice transcription errors
  "s|/users/|/Users/|g"
  "s|slash user/|/Users/|g"
  "s|slash users/|/Users/|g"
  "s|slash documents/|/Documents/|g"
  "s|slash desktop/|/Desktop/|g"
  "s|tilde/|~/|g"
  "s|home/|~/|g"
  "s|/home/|~/|g"
  "s|dot/|./|g"
  "s|dot dot/|../|g"
  "s|backslash|/|g"
  "s|underscore| |g"
  "s|colon slash slash|://|g"
  
  # Spaces and capitalization in common directory names
  "s|program files|Programs|g"
  "s|program files (x86)|Programs|g"
  "s|source code|src|g"
  "s|source|src|g"
  "s|javascript|JavaScript|g"
  "s|typescript|TypeScript|g"
  "s|my documents|Documents|g"
  "s|docs|Documents|g"
  "s|pics|Pictures|g"
)

# Auto-correct common voice dictation path errors
correct_path() {
  local original_path="$1"
  local corrected_path="$original_path"
  local changed=false
  
  # Apply common replacements
  for replacement in "${common_path_replacements[@]}"; do
    local old_path="$corrected_path"
    corrected_path=$(echo "$corrected_path" | sed -E "$replacement")
    if [ "$old_path" != "$corrected_path" ]; then
      changed=true
    fi
  done
  
  # Expand ~ if present
  if [[ "$corrected_path" == *"~"* ]]; then
    local old_path="$corrected_path"
    corrected_path="${corrected_path/#\~/$HOME}"
    if [ "$old_path" != "$corrected_path" ]; then
      changed=true
    fi
  fi
  
  # Notify about path correction if changed
  if [ "$changed" = true ] && [ "$original_path" != "$corrected_path" ]; then
    if [ "${FLASHFIND_USE_COLOR}" -eq 1 ]; then
      print_info "Path corrected: '$(print_yellow "$original_path")' → '$(print_green "$corrected_path")'"
    else
      echo "# FlashFind: Path corrected: '$original_path' → '$corrected_path'" >&2
    fi
  fi
  
  # Return corrected path
  echo "$corrected_path"
}

# Handle homonym and typo corrections for filenames
correct_filename() {
  local filename="$1"
  local directory="$2"
  
  # If directory doesn't exist, return original filename
  if [ ! -d "$directory" ]; then
    echo "$filename"
    return
  fi
  
  # Check if the exact filename exists
  if [ -e "$directory/$filename" ]; then
    echo "$filename"
    return
  fi
  
  # Try to find a close match using case-insensitive search
  local best_match=$(find "$directory" -maxdepth 1 -type f -iname "$filename" | head -n 1)
  if [ -n "$best_match" ]; then
    local best_match_basename=$(basename "$best_match")
    if [ "${FLASHFIND_USE_COLOR}" -eq 1 ]; then
      print_info "Filename corrected: '$(print_yellow "$filename")' → '$(print_green "$best_match_basename")'"
    else
      echo "# FlashFind: Filename corrected: '$filename' → '$best_match_basename'" >&2
    fi
    echo "$best_match_basename"
    return
  fi
  
  # Return original filename if no match found
  echo "$filename"
}

# Process a command line path to handle common dictation errors
process_voice_path() {
  local path="$1"
  
  # First correct the path structure
  local corrected_path=$(correct_path "$path")
  
  # Check if the corrected path exists
  if [ -e "$corrected_path" ]; then
    echo "$corrected_path"
    return
  fi
  
  # If path doesn't exist, try fuzzy matching if available
  if [ "${FLASHFIND_USE_FUZZY}" -eq 1 ]; then
    # Source fuzzy matching if available
    if [ -f "$(dirname "${BASH_SOURCE[0]}")/../fuzzy/finder.sh" ]; then
      source "$(dirname "${BASH_SOURCE[0]}")/../fuzzy/finder.sh"
      local fuzzy_result=$(find_closest_path "$corrected_path")
      if [ "$fuzzy_result" != "$corrected_path" ]; then
        echo "$fuzzy_result"
        return
      fi
    fi
  fi
  
  # If no match found, return the corrected path (at least fixed common errors)
  echo "$corrected_path"
}
