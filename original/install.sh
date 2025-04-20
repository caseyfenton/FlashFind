#!/bin/bash
# Mdfind_override installer script
# Automatically installs the find-to-mdfind converter system-wide

set -e # Exit on any error

# Script must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
INSTALL_DIR="/usr/local/etc/shell_extensions"

echo "=== Installing Mdfind_override ==="
echo "This will replace the 'find' command with an optimized 'mdfind' version system-wide."

# Create installation directory
mkdir -p "$INSTALL_DIR"
echo "✅ Created installation directory: $INSTALL_DIR"

# Copy the script
cp "$SCRIPT_DIR/src/find_to_mdfind.sh" "$INSTALL_DIR/"
chmod 755 "$INSTALL_DIR/find_to_mdfind.sh"
echo "✅ Installed find_to_mdfind.sh"

# Configure zsh
mkdir -p /etc/zshenv.d
cat > /etc/zshenv.d/find_to_mdfind.sh << 'EOF'
# Load find_to_mdfind converter
if [ -f /usr/local/etc/shell_extensions/find_to_mdfind.sh ]; then
  source /usr/local/etc/shell_extensions/find_to_mdfind.sh
  alias_find_to_mdfind
fi
EOF
echo "✅ Added zsh configuration"

# Configure bash
if grep -q "find_to_mdfind.sh" /etc/bashrc; then
  echo "ℹ️ Bash configuration already exists"
else
  cat >> /etc/bashrc << 'EOF'
# Load find_to_mdfind converter
if [ -f /usr/local/etc/shell_extensions/find_to_mdfind.sh ]; then
  source /usr/local/etc/shell_extensions/find_to_mdfind.sh
  alias_find_to_mdfind
fi
EOF
  echo "✅ Added bash configuration"
fi

echo ""
echo "✅ Installation complete! 🎉"
echo "The find-to-mdfind conversion will be active in all new terminal sessions."
echo "To activate in the current session, run:"
echo "  source /usr/local/etc/shell_extensions/find_to_mdfind.sh && alias_find_to_mdfind"
