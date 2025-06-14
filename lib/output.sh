#!/bin/bash
# Output formatting functions - single source of truth for all output

# Ensure we don't output if sourced multiple times
[[ -n "${_OUTPUT_SH_LOADED:-}" ]] && return 0
readonly _OUTPUT_SH_LOADED=1

# === Output Constants ===
readonly SYMBOL_SUCCESS="✓"
readonly SYMBOL_FAILURE="✗"

# === Section Headers ===
print_section() {
    # Removed per requirements - no section headers
    return 0
}

# === Prompts ===
# Usage: prompt "Question" "default_value"
# Returns: User input or default
prompt() {
    local question="$1"
    local default="${2:-}"
    local input
    
    if [[ -n "$default" ]]; then
        read -p "$question [$default]: " input
        echo "${input:-$default}"
    else
        read -p "$question: " input
        echo "$input"
    fi
}

# Usage: prompt_yn "Question" "default" (Y or N)
# Returns: 0 for yes, 1 for no
prompt_yn() {
    local question="$1"
    local default="${2:-Y}"
    local display prompt_text reply
    
    if [[ "$default" == "Y" ]]; then
        display="Y/n"
    else
        display="y/N"
    fi
    
    read -p "$question [$display] " -n 1 -r reply
    
    # Only add newline if user didn't press enter
    if [[ -n "$reply" ]]; then
        echo ""  # New line after single character input
    fi
    
    # Handle default
    if [[ -z "$reply" ]]; then
        reply="$default"
    fi
    
    # Return 0 for yes, 1 for no
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Usage: prompt_password "Question"
# Returns: Password (no echo)
prompt_password() {
    local question="$1"
    local password
    read -s -p "$question: " password
    echo ""  # New line after password
    echo "$password"
}

# === Progress Messages ===
# Usage: progress "Action description"
# Note: Must be followed by progress_done or progress_fail
progress() {
    echo -n "$1... "
}

progress_done() {
    echo "$SYMBOL_SUCCESS"
}

progress_fail() {
    echo "$SYMBOL_FAILURE"
}

# === Status Messages ===
success() {
    echo "$1 $SYMBOL_SUCCESS"
}

error() {
    echo "$SYMBOL_FAILURE Error: $1" >&2
    # If there's a second argument, show it as detail
    [[ -n "${2:-}" ]] && echo "  $2" >&2
}

# === Information ===
info() {
    echo "Note: $1"
}

message() {
    echo "$1"
}

# === Error Handling ===
# Usage: die "Error message" ["Detail message"]
die() {
    error "$@"
    exit 1
}