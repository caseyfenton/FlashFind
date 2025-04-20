#!/bin/bash
# FlashFind Installer Script
# Creates 'ff' command and optionally replaces 'find' with FlashFind
# Version: 1.0.0

set -e # Exit on errors

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default installation paths
INSTALL_DIR="${HOME}/.flashfind"
BIN_DIR="${HOME}/.local/bin"
CORE_SCRIPT="${INSTALL_DIR}/flashfind_core.sh"

# Print header
echo -e "${BLUE}
  ______ _           _     ______ _           _ 
 |  ____| |         | |   |  ____(_)         | |
 | |__  | | __ _ ___| |__ | |__   _ _ __   __| |
 |  __| | |/ _\` / __| '_ \|  __| | | '_ \ / _\` |
 | |    | | (_| \__ \ | | | |    | | | | | (_| |
 |_|    |_|\__,_|___/_| |_|_|    |_|_| |_|\__,_|
                                                
 Lightning-fast replacement for find using mdfind
 ${NC}
"

# Determine script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SOURCE_CORE="${SCRIPT_DIR}/src/flashfind_core.sh"

if [ ! -f "$SOURCE_CORE" ]; then
  echo -e "${RED}Error: Core script not found at $SOURCE_CORE${NC}"
  echo "Make sure you're running this script from the FlashFind project directory."
  exit 1
fi

# Create installation directories
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# Copy core script
cp "$SOURCE_CORE" "$CORE_SCRIPT"
chmod +x "$CORE_SCRIPT"

# Check if original find should be replaced
echo -e "${YELLOW}Installation Options:${NC}"
echo ""
echo "1) Install 'ff' command only (safest option)"
echo "2) Install 'ff' command AND replace system 'find' command"
echo ""
read -p "Choose an option [1/2] (default: 1): " choice

# Default to option 1 if no input
choice=${choice:-1}

# Create the ff command wrapper
cat > "${BIN_DIR}/ff" << EOF
#!/bin/bash
# FlashFind - Lightning-fast replacement for find
# Version: 1.0.0
exec "$CORE_SCRIPT" "\$@"
EOF
chmod +x "${BIN_DIR}/ff"

echo -e "${GREEN}✓ Installed 'ff' command${NC}"

# Install find replacement if requested
if [[ "$choice" == "2" ]]; then
  cat > "${BIN_DIR}/find" << EOF
#!/bin/bash
# FlashFind - Lightning-fast replacement for find
# Version: 1.0.0
exec "$CORE_SCRIPT" "\$@"
EOF
  chmod +x "${BIN_DIR}/find"
  echo -e "${GREEN}✓ Installed 'find' replacement${NC}"
  
  # Create an uninstaller that removes the find replacement
  cat > "${BIN_DIR}/flashfind-uninstall" << 'EOF'
#!/bin/bash
# FlashFind Uninstaller

INSTALL_DIR="${HOME}/.flashfind"
BIN_DIR="${HOME}/.local/bin"

# Remove find replacement if it exists
if [ -f "${BIN_DIR}/find" ]; then
  rm -f "${BIN_DIR}/find"
  echo "✓ Removed find replacement"
fi

# Remove ff command
if [ -f "${BIN_DIR}/ff" ]; then
  rm -f "${BIN_DIR}/ff"
  echo "✓ Removed ff command"
fi

# Remove uninstaller itself
rm -f "${BIN_DIR}/flashfind-uninstall"

# Prompt for complete removal
read -p "Remove FlashFind completely? [y/N]: " choice
choice=${choice:-n}
if [[ "$choice" =~ ^[Yy]$ ]]; then
  rm -rf "$INSTALL_DIR"
  echo "✓ Removed FlashFind completely"
fi

echo "FlashFind has been uninstalled successfully"
EOF
  chmod +x "${BIN_DIR}/flashfind-uninstall"
else
  # Create a simpler uninstaller that just removes ff
  cat > "${BIN_DIR}/flashfind-uninstall" << 'EOF'
#!/bin/bash
# FlashFind Uninstaller

INSTALL_DIR="${HOME}/.flashfind"
BIN_DIR="${HOME}/.local/bin"

# Remove ff command
if [ -f "${BIN_DIR}/ff" ]; then
  rm -f "${BIN_DIR}/ff"
  echo "✓ Removed ff command"
fi

# Remove uninstaller itself
rm -f "${BIN_DIR}/flashfind-uninstall"

# Prompt for complete removal
read -p "Remove FlashFind completely? [y/N]: " choice
choice=${choice:-n}
if [[ "$choice" =~ ^[Yy]$ ]]; then
  rm -rf "$INSTALL_DIR"
  echo "✓ Removed FlashFind completely"
fi

echo "FlashFind has been uninstalled successfully"
EOF
  chmod +x "${BIN_DIR}/flashfind-uninstall"
fi

echo -e "${GREEN}✓ Created uninstaller at ${BIN_DIR}/flashfind-uninstall${NC}"

# Check if bin directory is in PATH
if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
  echo -e "${YELLOW}Warning: ${BIN_DIR} is not in your PATH${NC}"
  echo "Add the following to your .bashrc or .zshrc file to add it:"
  echo ""
  echo "export PATH=\"\$PATH:${BIN_DIR}\""
  echo ""
fi

# Installation complete
echo -e "${GREEN}FlashFind installation complete!${NC}"
echo ""
echo -e "Usage:"
echo -e "  ${BLUE}ff path/to/search -name \"*.txt\"${NC} - Find files using FlashFind"
if [[ "$choice" == "2" ]]; then
  echo -e "  ${BLUE}find path/to/search -name \"*.txt\"${NC} - Also works with the 'find' command"
fi
echo -e "  ${BLUE}flashfind-uninstall${NC} - Uninstall FlashFind"
echo ""
echo -e "For complex operations (like -exec), FlashFind automatically falls back to standard find."
echo -e "Set ${YELLOW}FLASHFIND_DEBUG=1${NC} to see performance information."
echo ""
echo -e "${BLUE}Happy searching!${NC}"
