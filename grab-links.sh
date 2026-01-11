#!/usr/bin/env bash
# tmux-link-grab - URL seeking for tmux

set -euo pipefail

# Cleanup temporary files on exit
TMP_FILE=""
cleanup() {
    if [[ -n "$TMP_FILE" ]] && [[ -f "$TMP_FILE" ]]; then
        rm -f "$TMP_FILE"
    fi
}
trap cleanup EXIT INT TERM

# ============================================================================
# Configuration
# ============================================================================

# Get configuration from tmux options with defaults
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value
    option_value=$(tmux show-option -gqv "$option")
    echo "${option_value:-$default_value}"
}

SCROLLBACK_LINES=$(get_tmux_option "@link-grab-lines" "200")
BROWSER=$(get_tmux_option "@link-grab-browser" "${BROWSER:-xdg-open}")

# URL regex patterns
REGEX_HTTP='https?://[a-zA-Z0-9./?#:@!$&'\''()*+,;=_~%-]+'
REGEX_LOCALHOST='https?://localhost(:[0-9]+)?(/[a-zA-Z0-9./?#:@!$&'\''()*+,;=_~%-]*)?'
REGEX_FTP='ftp://[a-zA-Z0-9./?#:@!$&'\''()*+,;=_~%-]+'
REGEX_IPV4='(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(:[0-9]+)?'
REGEX_LOCALHOST_PORT='localhost:[0-9]+'

# ============================================================================
# Dependency Checks
# ============================================================================

check_dependencies() {
    if ! command -v fzf &> /dev/null; then
        tmux display-message "Error: fzf is not installed"
        exit 1
    fi
}

# ============================================================================
# Clipboard Functions
# ============================================================================

# Detect and use available clipboard tool
copy_to_clipboard() {
    local text="$1"
    
    if command -v pbcopy &> /dev/null; then
        # macOS
        echo -n "$text" | pbcopy
    elif command -v xclip &> /dev/null; then
        # Linux X11
        echo -n "$text" | xclip -selection clipboard
    elif command -v wl-copy &> /dev/null; then
        # Linux Wayland
        echo -n "$text" | wl-copy
    else
        # Fallback to tmux buffer (always available in tmux context)
        tmux set-buffer "$text"
        tmux display-message "✓ copied to tmux buffer (no system clipboard tool found)"
        return 0
    fi
    
    tmux display-message "✓ copied to clipboard"
}

# ============================================================================
# Browser Functions
# ============================================================================

open_in_browser() {
    local url="$1"
    
    if command -v "$BROWSER" &> /dev/null; then
        "$BROWSER" "$url" &> /dev/null &
        tmux display-message "✓ opened in browser"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$url" &> /dev/null &
        tmux display-message "✓ opened in browser"
    elif command -v open &> /dev/null; then
        # macOS
        open "$url" &> /dev/null &
        tmux display-message "✓ opened in browser"
    else
        tmux display-message "Error: no browser command found"
        return 1
    fi
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    check_dependencies
    
    # Capture pane content
    local content
    content=$(tmux capture-pane -pJ -S "-${SCROLLBACK_LINES}" 2>/dev/null || echo "")
    
    if [[ -z "$content" ]]; then
        tmux display-message "Error: failed to capture pane content"
        exit 1
    fi
    
    # Extract URLs and IPs with improved regex patterns
    local urls
    urls=$(echo "$content" | grep -oE \
        "${REGEX_HTTP}|${REGEX_LOCALHOST}|${REGEX_FTP}|${REGEX_IPV4}|${REGEX_LOCALHOST_PORT}" \
        || echo "")
    
    if [[ -z "$urls" ]]; then
        tmux display-message "No URLs found in scrollback"
        exit 0
    fi
    
    # Remove duplicates and reverse (most recent first)
    urls=$(echo "$urls" | awk '!seen[$0]++' | tac)
    
    # Create secure temporary file for space key handling
    TMP_FILE=$(mktemp)
    
    # Present URLs with fzf
    local selected
    selected=$(echo "$urls" | fzf \
        --height=80% \
        --reverse \
        --header='↵ copy | Space open | Esc cancel' \
        --bind "space:execute(echo {} > $TMP_FILE)+abort" \
        --expect=space \
        || echo "")
    
    # Handle selection
    if [[ -f "$TMP_FILE" ]] && [[ -s "$TMP_FILE" ]]; then
        local url
        url=$(cat "$TMP_FILE")
        if [[ -n "$url" ]]; then
            open_in_browser "$url"
        fi
    elif [[ -n "$selected" ]]; then
        copy_to_clipboard "$selected"
    fi
}

main "$@"
