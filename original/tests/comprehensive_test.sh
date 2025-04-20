#!/bin/bash
# Comprehensive test suite for find_to_mdfind
# Tests all common permutations of find arguments

# Source the converter
source ../src/find_to_mdfind.sh
alias_find_to_mdfind

# Create a test directory with sample files
TEST_DIR="/tmp/mdfind_test"
mkdir -p "$TEST_DIR"
mkdir -p "$TEST_DIR/subdir1" "$TEST_DIR/subdir2/subsubdir"
touch "$TEST_DIR/file1.txt" "$TEST_DIR/file2.pdf" "$TEST_DIR/subdir1/file3.docx" 
touch "$TEST_DIR/subdir2/file4.jpg" "$TEST_DIR/subdir2/subsubdir/file5.log"
touch "$TEST_DIR/.hidden_file"

# Helpers
separator() {
  echo -e "\n=== $1 ===\n"
}

run_test() {
  local test_name="$1"
  local command="$2"
  separator "Testing: $test_name"
  echo "Command: $command"
  eval "$command"
}

# Test 1: Basic find with no arguments
run_test "Basic find" "find $TEST_DIR"

# Test 2: Find by name (exact)
run_test "Find by name (exact)" "find $TEST_DIR -name 'file1.txt'"

# Test 3: Find by name (wildcard)
run_test "Find by name (wildcard)" "find $TEST_DIR -name '*.pdf'"

# Test 4: Find by name (case insensitive)
run_test "Find by name (case insensitive)" "find $TEST_DIR -iname '*.JPG'"

# Test 5: Find by type (file)
run_test "Find by type (file)" "find $TEST_DIR -type f"

# Test 6: Find by type (directory)
run_test "Find by type (directory)" "find $TEST_DIR -type d"

# Test 7: Find with maxdepth
run_test "Find with maxdepth" "find $TEST_DIR -maxdepth 1"

# Test 8: Find with multiple conditions (AND)
run_test "Find with multiple conditions (AND)" "find $TEST_DIR -name '*.txt' -type f"

# Test 9: Combining path and name
run_test "Combining path and name" "find $TEST_DIR/subdir2 -name '*.jpg'"

# Test 10: Find hidden files
run_test "Find hidden files" "find $TEST_DIR -name '.*'"

# Test 11: Find with path pattern
run_test "Find with path pattern" "find $TEST_DIR -path '*sub*'"

# Test 12: Find with negation
run_test "Find with negation" "find $TEST_DIR -not -name '*.txt'"

# Test 13: Complex find (OR conditions)
run_test "Complex find (OR conditions)" "find $TEST_DIR \\( -name '*.pdf' -o -name '*.docx' \\)"

# Test 14: Find with size condition
run_test "Find with size condition" "find $TEST_DIR -size -10k"

# Test 15: Find with grep pipe
run_test "Find with grep pipe" "find $TEST_DIR -type f -name '*.txt' | grep 'file'"

# Test 16: Find with exec
run_test "Find with exec" "find $TEST_DIR -type f -name '*.txt' -exec ls -la {} \\;"

# Test 17: Find with modification time
run_test "Find with modification time" "find $TEST_DIR -mtime -1"

# Test 18: Find with newer than
touch "$TEST_DIR/reference_file"
run_test "Find with newer than" "find $TEST_DIR -newer $TEST_DIR/reference_file"

# Test 19: Find with depth
run_test "Find with depth" "find $TEST_DIR -mindepth 2"

# Test 20: Find with mixed complex conditions
run_test "Find with mixed complex conditions" "find $TEST_DIR -type f \\( -name '*.txt' -o -name '*.pdf' \\) -size -100k"

# Test 21: Find direct subdirectories only
run_test "Find direct subdirectories only" "find $TEST_DIR -maxdepth 1 -type d"

# Test 22: Find empty files
run_test "Find empty files" "find $TEST_DIR -type f -empty"

# Test 23: Find with literal path
run_test "Find with literal path" "find $TEST_DIR -path '$TEST_DIR/subdir1'"

# Test 24: Find files with spaces in name
touch "$TEST_DIR/file with spaces.txt"
run_test "Find files with spaces in name" "find \"$TEST_DIR\" -name \"*spaces*\""

# Test 25: Find with multiple directories
run_test "Find with multiple directories" "find $TEST_DIR/subdir1 $TEST_DIR/subdir2"

# Clear test directory 
separator "Test complete"
echo "Cleaning up test files..."
rm -rf "$TEST_DIR"
