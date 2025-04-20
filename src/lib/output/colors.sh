# FILE: src/lib/output/colors.sh
#!/usr/bin/env bash
# FlashFind Color Utilities
set -o nounset; set -o pipefail; export LANG=C
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$DIR/../core/config.sh"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; GRAY='\033[0;90m'; BOLD='\033[1m'; RESET='\033[0m'
if [ "$FLASHFIND_USE_COLOR" -eq 0 ]; then RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; GRAY=''; BOLD=''; RESET=''; fi
print_error()   { echo -e "${RED}✘ Error: $1${RESET}" >&2; }
print_warning() { echo -e "${YELLOW}⚠ Warning: $1${RESET}" >&2; }
print_success() { echo -e "${GREEN}✓ Success: $1${RESET}" >&2; }
print_info()    { echo -e "${BLUE}ℹ $1${RESET}" >&2; }
print_debug()   { [ "$FLASHFIND_DEBUG" -eq 1 ] && echo -e "${GRAY}⟫ Debug: $1${RESET}" >&2; }

