#!/usr/bin/env bash
# tmux-link-grab - URL seeking for tmux

set -euo pipefail

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
    elif command -v tmux &> /dev/null; then
        # Fallback to tmux buffer
        tmux set-buffer "$text"
        tmux display-message "✓ copied to tmux buffer (no system clipboard tool found)"
        return 0
    else
        tmux display-message "Error: no clipboard tool found (pbcopy/xclip/wl-copy)"
        return 1
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
        'https?://[a-zA-Z0-9./?#:@!$&'\''()*+,;=_~%-]+|'\
'https?://localhost(:[0-9]+)?(/[a-zA-Z0-9./?#:@!$&'\''()*+,;=_~%-]*)?|'\
'ftp://[a-zA-Z0-9./?#:@!$&'\''()*+,;=_~%-]+|'\
'[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:[0-9]+)?|'\
'localhost:[0-9]+' \
        || echo "")
    
    if [[ -z "$urls" ]]; then
        tmux display-message "No URLs found in scrollback"
        exit 0
    fi
    
    # Remove duplicates and reverse (most recent first)
    urls=$(echo "$urls" | awk '!seen[$0]++' | tac)
    
    # Present URLs with fzf
    local selected
    selected=$(echo "$urls" | fzf \
        --height=80% \
        --reverse \
        --header='↵ copy | Space open | Esc cancel' \
        --bind 'space:execute(echo {} > /tmp/tmux-link-grab-open)+abort' \
        --expect=space \
        || echo "")
    
    # Handle selection
    if [[ -f /tmp/tmux-link-grab-open ]]; then
        local url
        url=$(cat /tmp/tmux-link-grab-open)
        rm -f /tmp/tmux-link-grab-open
        if [[ -n "$url" ]]; then
            open_in_browser "$url"
        fi
    elif [[ -n "$selected" ]]; then
        copy_to_clipboard "$selected"
    fi
}

main "$@"
