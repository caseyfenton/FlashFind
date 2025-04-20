#!/bin/bash
# FlashFind - Lightning-fast replacement for find using mdfind
# Optimized for vibe coding (voice-to-text + LLM) interactions
# Version: 1.0.0

# Script directory for module loading
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Load core modules
source "${SCRIPT_DIR}/lib/core/config.sh"
source "${SCRIPT_DIR}/lib/output/colors.sh"
source "${SCRIPT_DIR}/lib/diagnostics/spotlight.sh"
source "${SCRIPT_DIR}/lib/vibe/path_correction.sh"
source "${SCRIPT_DIR}/lib/core/history.sh"
source "${SCRIPT_DIR}/lib/core/converter.sh"

# Enable strict error handling
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
  echo "  ff . --vibe-mode                   Enable all vibe coding features"
  echo "  ff /user/documents -name \"*.md\"    Auto-corrects path to /Users/Documents"
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

# Check mdfind health before using it
if ! check_mdfind_health; then
  /usr/bin/find "$@"
  exit $?
fi

# Extract special flags from arguments
VIBE_MODE=false
SUMMARY_MODE=false
CONTENT_MODE=false
PREVIEW_ALL=false

# Process special flags
NEW_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --vibe-mode)
      VIBE_MODE=true
      FLASHFIND_VIBE_MODE=1
      print_info "Vibe coding mode enabled"
      ;;
    --summary)
      SUMMARY_MODE=true
      ;;
    --content)
      CONTENT_MODE=true
      ;;
    --preview-all)
      PREVIEW_ALL=true
      ;;
    --benchmark)
      # Run a benchmark comparison
      shift
      benchmark_mdfind "$@"
      exit $?
      ;;
    --spotlight-status)
      # Show spotlight status
      get_spotlight_status
      exit $?
      ;;
    --history)
      # Show search history
      get_frequent_patterns 10
      exit $?
      ;;
    *)
      NEW_ARGS+=("$arg")
      ;;
  esac
done

# If vibe mode is enabled, turn on all features
if [ "$VIBE_MODE" = true ]; then
  SUMMARY_MODE=true
  CONTENT_MODE=true
fi

# Suggest from history if relevant to this search
if [[ "${NEW_ARGS[*]}" == *"-name"* && "${NEW_ARGS[*]}" != *"-name "*\"* ]]; then
  suggest_from_history
fi

# Convert find arguments to mdfind and execute
RESULTS_FILE=$(convert_to_mdfind "${NEW_ARGS[@]}")
CONVERT_STATUS=$?

# If conversion failed, fall back to standard find
if [ $CONVERT_STATUS -ne 0 ]; then
  /usr/bin/find "$@"
  exit $?
fi

# Process results based on mode
if [ "$SUMMARY_MODE" = true ]; then
  format_summary_results "$(cat "$RESULTS_FILE")"
elif [ "$CONTENT_MODE" = true ]; then
  format_content_preview "$(cat "$RESULTS_FILE")"
else
  # Standard output
  cat "$RESULTS_FILE" | grep -v "^$" || true
fi

# Clean up temp file
rm -f "$RESULTS_FILE" 2>/dev/null

exit 0
