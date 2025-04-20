#!/bin/bash
# Mdfind_override uninstaller script
# Removes all system-wide find-to-mdfind converter components

set -e # Exit on any error

# Script must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo"
  exit 1
fi

INSTALL_DIR="/usr/local/etc/shell_extensions"

echo "=== Uninstalling Mdfind_override ==="

# Remove the script
if [ -f "$INSTALL_DIR/find_to_mdfind.sh" ]; then
  rm -f "$INSTALL_DIR/find_to_mdfind.sh"
  echo "✅ Removed find_to_mdfind.sh"
else
  echo "ℹ️ Script not found at $INSTALL_DIR/find_to_mdfind.sh"
fi

# Remove zsh configuration
if [ -f "/etc/zshenv.d/find_to_mdfind.sh" ]; then
  rm -f "/etc/zshenv.d/find_to_mdfind.sh"
  echo "✅ Removed zsh configuration"
else
  echo "ℹ️ ZSH configuration not found"
fi

# Remove bash configuration (more carefully)
if grep -q "find_to_mdfind.sh" /etc/bashrc; then
  # Create a temporary file with the lines we want to remove excluded
  grep -v "find_to_mdfind.sh" /etc/bashrc > /tmp/new_bashrc
  # Replace the original file
  mv /tmp/new_bashrc /etc/bashrc
  echo "✅ Removed bash configuration"
else
  echo "ℹ️ Bash configuration not found"
fi

echo ""
echo "✅ Uninstallation complete! 🎉"
echo "The find-to-mdfind conversion has been removed."
echo "Please restart your terminal sessions for the changes to take effect."
