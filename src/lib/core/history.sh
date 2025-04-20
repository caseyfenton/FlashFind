#!/bin/bash
# FlashFind Core Module - History
# Handles search history and pattern tracking

# Import config if not already loaded
if [ -z "${FLASHFIND_VERSION}" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

# Load coloring utilities
source "$(dirname "${BASH_SOURCE[0]}")/../output/colors.sh"

# Add a search pattern to history
add_to_history() {
  local pattern="$1"
  
  # Don't save empty patterns
  if [ -z "$pattern" ]; then
    return
  fi
  
  # Check if pattern already exists to avoid duplicates
  if ! grep -q "^$pattern$" "$HISTORY_FILE" 2>/dev/null; then
    # Add to beginning of file (more recent patterns first)
    echo "$pattern" | cat - "$HISTORY_FILE" > /tmp/flashfind_history.$$ && mv /tmp/flashfind_history.$$ "$HISTORY_FILE"
    # Keep only the most recent patterns based on config
    head -n "${FLASHFIND_MAX_HISTORY}" "$HISTORY_FILE" > /tmp/flashfind_history.$$ && mv /tmp/flashfind_history.$$ "$HISTORY_FILE"
    print_debug "Added pattern to history: $pattern"
  fi
}

# Get recent search patterns
get_recent_patterns() {
  local count="${1:-3}"
  
  if [ -f "$HISTORY_FILE" ]; then
    head -n "$count" "$HISTORY_FILE"
  fi
}

# Show recent search patterns to the user
suggest_from_history() {
  if [ -f "$HISTORY_FILE" ] && [ -s "$HISTORY_FILE" ]; then
    print_info "Recent search patterns:"
    get_recent_patterns 3 | while read -r pattern; do
      echo "  $(print_cyan "•") $(print_gray "$pattern")" >&2
    done
  fi
}

# Clear search history
clear_history() {
  > "$HISTORY_FILE"
  print_success "Search history cleared"
}

# Get the most frequent search patterns
get_frequent_patterns() {
  local count="${1:-5}"
  
  if [ -f "$HISTORY_FILE" ] && [ -s "$HISTORY_FILE" ]; then
    print_info "Most frequent search patterns:"
    sort "$HISTORY_FILE" | uniq -c | sort -rn | head -n "$count" | while read -r frequency pattern; do
      echo "  $(print_cyan "•") $(print_gray "$pattern") (${frequency}×)" >&2
    done
  fi
}

# Export search history as JSON
export_history_json() {
  local output_file="${1:-$FLASHFIND_DIR/history_export.json}"
  
  if [ -f "$HISTORY_FILE" ] && [ -s "$HISTORY_FILE" ]; then
    echo "{" > "$output_file"
    echo "  \"patterns\": [" >> "$output_file"
    
    local first=true
    while IFS= read -r pattern; do
      if [ "$first" = true ]; then
        echo "    \"$pattern\"" >> "$output_file"
        first=false
      else
        echo "    ,\"$pattern\"" >> "$output_file"
      fi
    done < "$HISTORY_FILE"
    
    echo "  ]" >> "$output_file"
    echo "}" >> "$output_file"
    
    print_success "History exported to: $output_file"
  else
    print_warning "No history to export"
  fi
}
