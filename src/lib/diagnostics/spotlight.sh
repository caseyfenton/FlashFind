#!/bin/bash
# FlashFind Diagnostics Module - Spotlight
# Handles troubleshooting and diagnostics for Spotlight/mdfind issues

# Import config if not already loaded
if [ -z "${FLASHFIND_VERSION}" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"
fi

# Load coloring utilities
source "$(dirname "${BASH_SOURCE[0]}")/../output/colors.sh"

# Check if mdfind is working properly and diagnose issues
check_mdfind_health() {
  print_debug "Checking mdfind health..."
  
  # Test basic mdfind functionality with timeout to prevent hanging
  if ! timeout 5 mdfind -count -onlyin "$HOME" "kMDItemFSName = '*'" &>/dev/null; then
    print_warning "mdfind appears to be having issues. Running diagnostics..."
    
    # Run a series of diagnostic checks
    local issues_found=0
    local fix_commands=()
    
    # Check 1: Is Spotlight enabled?
    if ! mdutil -s / | grep -q "Indexing enabled"; then
      print_error "Spotlight indexing is disabled"
      fix_commands+=("sudo mdutil -i on /")
      issues_found=1
    fi
    
    # Check 2: Is Spotlight actively indexing?
    if mdutil -s / | grep -q "Indexing"; then
      print_warning "Spotlight is currently indexing, which may affect performance"
      issues_found=1
    fi
    
    # Check 3: Is the current directory excluded from Spotlight?
    if defaults read /.Spotlight-V100/VolumeConfiguration.plist Exclusions 2>/dev/null | grep -q "$PWD"; then
      print_error "Current directory is excluded from Spotlight"
      print_info "Check System Settings → Spotlight → Privacy"
      issues_found=1
    fi
    
    # Check 4: Basic test on root directory
    if ! timeout 5 mdfind -onlyin / "kMDItemFSName = 'Library'" &>/dev/null; then
      print_error "mdfind query failed on root directory"
      fix_commands+=("sudo mdutil -E /")
      issues_found=1
    fi
    
    # Check 5: Is mdutil running properly?
    if ! pgrep -q "mdworker"; then
      print_error "No mdworker processes found running"
      fix_commands+=("sudo killall -KILL mdworker mdworker_shared mds mdsync")
      fix_commands+=("sudo launchctl stop com.apple.metadata.mds && sudo launchctl start com.apple.metadata.mds")
      issues_found=1
    fi
    
    # Check 6: Verify Spotlight database permissions
    if [ ! -d "/.Spotlight-V100" ] || [ ! -r "/.Spotlight-V100" ]; then
      print_error "Spotlight database folder has permission issues"
      fix_commands+=("sudo chmod -R 755 /.Spotlight-V100")
      issues_found=1
    fi
    
    # If issues were found, suggest fixes
    if [ $issues_found -eq 1 ]; then
      print_info "Suggested fixes:"
      for cmd in "${fix_commands[@]}"; do
        echo "  $(print_yellow "$cmd")"
      done
      print_info "For severe issues, try rebuilding the Spotlight index:"
      echo "  $(print_yellow "sudo mdutil -E /")"
      
      # Save diagnostic information for reference
      local diagnostic_file="${FLASHFIND_DIR}/mdfind_diagnostic.log"
      {
        echo "FlashFind mdfind Diagnostic Report"
        echo "Date: $(date)"
        echo "-----------------------------"
        echo "mdutil status:"
        mdutil -s / 2>&1
        echo ""
        echo "Spotlight processes:"
        ps aux | grep -E "md(worker|s)" 2>&1
        echo ""
        echo "Spotlight exclusions:"
        defaults read /.Spotlight-V100/VolumeConfiguration.plist Exclusions 2>&1
        echo ""
        echo "Suggested fixes:"
        for cmd in "${fix_commands[@]}"; do
          echo "  $cmd"
        done
      } > "$diagnostic_file"
      
      print_info "Diagnostic information saved to: $diagnostic_file"
      print_warning "Falling back to standard find for reliability"
      return 1
    fi
  fi
  
  print_debug "mdfind is working properly"
  return 0
}

# Tests mdfind performance against regular find
benchmark_mdfind() {
  local path="$1"
  local query="$2"
  
  # Default to home directory if not specified
  if [ -z "$path" ]; then
    path="$HOME"
  fi
  
  # Default to all files if not specified
  if [ -z "$query" ]; then
    query="*"
  fi
  
  print_info "Benchmarking mdfind vs find in $(print_yellow "$path") for pattern $(print_yellow "$query")"
  
  # Prepare mdfind query
  local mdfind_query="kMDItemFSName = '$query'"
  
  # Time the mdfind command
  print_info "Running mdfind..."
  local mdfind_start=$(date +%s.%N)
  local mdfind_count=$(mdfind -onlyin "$path" "$mdfind_query" | wc -l)
  local mdfind_end=$(date +%s.%N)
  local mdfind_time=$(echo "$mdfind_end - $mdfind_start" | bc)
  
  # Time the find command
  print_info "Running find..."
  local find_start=$(date +%s.%N)
  local find_count=$(find "$path" -name "$query" 2>/dev/null | wc -l)
  local find_end=$(date +%s.%N)
  local find_time=$(echo "$find_end - $find_start" | bc)
  
  # Calculate speedup
  local speedup=$(echo "scale=1; $find_time / $mdfind_time" | bc)
  
  # Print results
  echo ""
  echo "$(print_bold "Performance Comparison")"
  echo "----------------------------------------"
  echo "$(print_bold "Command      | Time (s)  | Files Found")"
  echo "----------------------------------------"
  echo "$(print_green "mdfind       | $mdfind_time | $mdfind_count")"
  echo "$(print_yellow "find         | $find_time | $find_count")"
  echo "----------------------------------------"
  echo "$(print_bold "Speedup: ${speedup}x")"
  echo ""
  
  # Check for discrepancies in results
  if [ "$mdfind_count" -ne "$find_count" ]; then
    print_warning "Result count differs between mdfind ($mdfind_count) and find ($find_count)"
    print_info "This may be due to Spotlight indexing status or exclusions"
  fi
  
  # Record benchmark in history
  local benchmark_file="${FLASHFIND_DIR}/benchmarks.log"
  {
    echo "Date: $(date)"
    echo "Path: $path"
    echo "Query: $query"
    echo "mdfind time: $mdfind_time seconds, found $mdfind_count files"
    echo "find time: $find_time seconds, found $find_count files"
    echo "Speedup: ${speedup}x"
    echo "----------------------------------------"
  } >> "$benchmark_file"
  
  print_info "Benchmark results saved to: $benchmark_file"
}

# Check if Spotlight is actively indexing
is_spotlight_indexing() {
  if mdutil -s / | grep -q "Indexing in progress"; then
    return 0
  else
    return 1
  fi
}

# Get Spotlight database status and statistics
get_spotlight_status() {
  local status_file="${FLASHFIND_DIR}/spotlight_status.log"
  
  print_info "Checking Spotlight status..."
  
  {
    echo "FlashFind Spotlight Status Report"
    echo "Date: $(date)"
    echo "-----------------------------"
    echo "mdutil status for volumes:"
    mdutil -s / 2>&1
    mdutil -s /Volumes/* 2>&1 2>/dev/null
    echo ""
    echo "Spotlight processes:"
    ps aux | grep -E "md(worker|s)" 2>&1
    echo ""
    echo "Spotlight index size:"
    du -sh /.Spotlight-V100 2>&1
    echo ""
    echo "Spotlight exclusions:"
    defaults read /.Spotlight-V100/VolumeConfiguration.plist Exclusions 2>&1
  } > "$status_file"
  
  print_success "Spotlight status saved to: $status_file"
  print_info "To view the status, run: $(print_yellow "cat $status_file")"
}
