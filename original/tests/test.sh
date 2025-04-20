#!/bin/bash
# Test script for find_to_mdfind

# Source the converter
source ../src/find_to_mdfind.sh
alias_find_to_mdfind

# Run a test command
echo "=== Testing find conversion ==="
find . -name "*.sh" -type f

echo ""
echo "=== Testing more complex find command ==="
find /Users -name "*.json" -type f -mtime -7 | head -5

echo ""
echo "✅ Tests completed"
