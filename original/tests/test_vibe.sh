#!/usr/bin/env bash
set -euo pipefail
# Test FlashFind Vibe Coding Features: path correction
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)/../../src/lib/vibe"
source "$DIR/path_correction.sh"

echo "Testing special character handling..."
output=$(correct_path "/user/Documents/test dash file dot txt")
expected="/Users/Documents/test-file.txt"
if [[ "$output" != "$expected" ]]; then
  echo "❌ special char handling failed: got $output, expected $expected"
  exit 1
else
  echo "✅ special char handling OK"
fi

echo "Testing capitalization resolution..."
output=$(correct_path "/documents/test.md")
expected="/Documents/test.md"
if [[ "$output" != "$expected" ]]; then
  echo "❌ capitalization resolution failed: got $output, expected $expected"
  exit 1
else
  echo "✅ capitalization resolution OK"
fi

echo "Testing tilde expansion..."
output=$(correct_path "tilde/Downloads/file.txt")
expected="$HOME/Downloads/file.txt"
if [[ "$output" != "$expected" ]]; then
  echo "❌ tilde expansion failed: got $output, expected $expected"
  exit 1
else
  echo "✅ tilde expansion OK"
fi

echo "All vibe tests passed."
