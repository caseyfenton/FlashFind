#!/bin/bash
# FlashFind Output Module - Colors
# Handles color and formatting for console output

# Import config if not already loaded
if [ -z "${FLASHFIND_VERSION}" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"
fi

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

# Check if color should be disabled
if [ "${FLASHFIND_USE_COLOR:-1}" -eq 0 ]; then
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  MAGENTA=""
  CYAN=""
  GRAY=""
  BOLD=""
  RESET=""
fi

# Print colored text
print_red() {
  echo -e "${RED}${1}${RESET}"
}

print_green() {
  echo -e "${GREEN}${1}${RESET}"
}

print_yellow() {
  echo -e "${YELLOW}${1}${RESET}"
}

print_blue() {
  echo -e "${BLUE}${1}${RESET}"
}

print_magenta() {
  echo -e "${MAGENTA}${1}${RESET}"
}

print_cyan() {
  echo -e "${CYAN}${1}${RESET}"
}

print_gray() {
  echo -e "${GRAY}${1}${RESET}"
}

print_bold() {
  echo -e "${BOLD}${1}${RESET}"
}

# Print formatted messages
print_error() {
  echo -e "${RED}✘ Error: ${1}${RESET}" >&2
}

print_warning() {
  echo -e "${YELLOW}⚠ Warning: ${1}${RESET}" >&2
}

print_success() {
  echo -e "${GREEN}✓ Success: ${1}${RESET}" >&2
}

print_info() {
  echo -e "${BLUE}ℹ ${1}${RESET}" >&2
}

print_debug() {
  if [ "${FLASHFIND_DEBUG:-0}" -eq 1 ]; then
    echo -e "${GRAY}⟫ Debug: ${1}${RESET}" >&2
  fi
}

# Format search results for better readability
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
    echo -e "${YELLOW}No matching files found.${RESET}"
    return
  fi
  
  echo -e "${GREEN}Found ${BOLD}$count${RESET}${GREEN} matching files.${RESET}"
  
  if [ "$count" -le 5 ]; then
    echo -e "${BOLD}Files:${RESET}"
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then
        echo -e "  ${BLUE}•${RESET} $line"
      fi
    done <<< "$results"
  else
    echo -e "${BOLD}Examples:${RESET}"
    local examples=0
    while IFS= read -r line; do
      if [[ -n "$line" && "$examples" -lt 3 ]]; then
        echo -e "  ${BLUE}•${RESET} $line"
        ((examples++))
      fi
    done <<< "$results"
    echo -e "  ${GRAY}... and $(($count - 3)) more files${RESET}"
  fi
}

# Format content preview for better readability
format_content_preview() {
  local results="$1"
  local preview_count=0
  local max_previews=3
  
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
        echo -e "  ${GRAY}... and $remaining more files (use --preview-all to show all)${RESET}"
      fi
      break
    fi
    
    # Only preview text files
    if [[ -f "$file" ]] && file "$file" | grep -q text; then
      echo -e "${CYAN}=== ${BOLD}$file${RESET} ${CYAN}===${RESET}"
      local line_count=0
      while IFS= read -r content_line && [ "$line_count" -lt 5 ]; do
        echo "  $content_line"
        ((line_count++))
      done < "$file"
      echo -e "  ${GRAY}...${RESET}"
      echo ""
      preview_count=$((preview_count + 1))
    fi
  done <<< "$results"
}
