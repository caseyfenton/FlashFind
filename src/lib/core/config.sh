#!/bin/bash
# FlashFind Core Configuration Module
# Handles global configuration settings and environment variables

# Version information
FLASHFIND_VERSION="1.0.0"

# Paths
FLASHFIND_DIR="${HOME}/.flashfind"
HISTORY_FILE="${FLASHFIND_DIR}/history"
CACHE_DIR="${FLASHFIND_DIR}/cache"
CONFIG_FILE="${FLASHFIND_DIR}/config"

# Ensure directories exist
setup_dirs() {
  mkdir -p "${FLASHFIND_DIR}" "${CACHE_DIR}"
  # Initialize files if they don't exist
  touch "${HISTORY_FILE}"
}

# Load configuration from file or use defaults
load_config() {
  # Create config file with defaults if it doesn't exist
  if [ ! -f "${CONFIG_FILE}" ]; then
    cat > "${CONFIG_FILE}" << EOL
# FlashFind Configuration
FLASHFIND_DEBUG=0
FLASHFIND_USE_FUZZY=1
FLASHFIND_MAX_HISTORY=20
FLASHFIND_VIBE_MODE=0
FLASHFIND_USE_COLOR=1
EOL
  fi
  
  # Source the config file
  source "${CONFIG_FILE}"
  
  # Set defaults for any missing values
  FLASHFIND_DEBUG="${FLASHFIND_DEBUG:-0}"
  FLASHFIND_USE_FUZZY="${FLASHFIND_USE_FUZZY:-1}"
  FLASHFIND_MAX_HISTORY="${FLASHFIND_MAX_HISTORY:-20}"
  FLASHFIND_VIBE_MODE="${FLASHFIND_VIBE_MODE:-0}"
  FLASHFIND_USE_COLOR="${FLASHFIND_USE_COLOR:-1}"
}

# Initialize configuration on module load
setup_dirs
load_config
