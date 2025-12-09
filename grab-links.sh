#!/bin/bash

# tmux-link-grab - elegant URL/IP/file path seeking for tmux
# Hit prefix+s, numbers appear on URLs/IPs/paths, type number, get highlighted flash of confirmation
# License: GNU GPL v3

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCROLLBACK_LINES=100
FLASH_COUNT=2
FLASH_DURATION=0.1

# Detect clipboard command based on OS
detect_clipboard() {
  if command -v pbcopy &>/dev/null; then
    echo "pbcopy"
  elif command -v xclip &>/dev/null; then
    echo "xclip -selection clipboard"
  elif command -v wl-copy &>/dev/null; then
    echo "wl-copy"
  else
    return 1
  fi
}

# ============================================================================
# DEPENDENCY CHECKS
# ============================================================================

check_dependencies() {
  local missing=()

  for cmd in tmux grep fzf; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if ! CLIPBOARD=$(detect_clipboard); then
    missing+=("clipboard tool (pbcopy/xclip/wl-copy)")
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    echo "tmux-link-grab: Missing dependencies: ${missing[*]}" >&2
    return 1
  fi

  return 0
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

main() {
  local window="${1:-$(tmux display-message -p '#{window_id}')}"

  # Check all dependencies exist
  if ! check_dependencies; then
    tmux display-message "tmux-link-grab: Missing dependencies" 2>/dev/null || exit 1
  fi

  # Extract URLs, IPs, and file paths from ALL PANES in current window
  # Pattern matches:
  #   - https://example.com
  #   - http://example.com
  #   - ftp://example.com
  #   - 192.168.1.1
  #   - /absolute/paths
  #   - ~/home/paths
  #   - ./relative/paths
  local items
  items=$(tmux capture-pane -p -S "-${SCROLLBACK_LINES}" -t "$window" 2>/dev/null | \
    grep -oE '(https?|ftp)://[^ ]+|([0-9]{1,3}\.){3}[0-9]{1,3}|~?/?[./]?[a-zA-Z0-9._/-]+' | \
    sort -u)

  if [ -z "$items" ]; then
    tmux display-message "tmux-link-grab: No URLs, IPs, or paths found" 2>/dev/null || true
    return 1
  fi

  # Let user pick from numbered list using fzf (no redirection to allow TTY)
  local choice
  choice=$(echo "$items" | nl -w1 -s'. ' | \
    fzf --no-preview \
      --height 50% \
      --bind 'enter:accept' \
      --bind 'esc:abort' \
      --color 'hl:196')

  if [ -z "$choice" ]; then
    return 0
  fi

  # Extract the item by removing leading "N. "
  local item="${choice#[0-9]*. }"

  # Copy to clipboard using detected method
  if echo -n "$item" | $CLIPBOARD 2>/dev/null; then
    # Flash status bar for visual confirmation
    flash_confirmation "$window"
    tmux display-message "Copied: $item" 2>/dev/null || true
    return 0
  else
    tmux display-message "tmux-link-grab: Failed to copy to clipboard" 2>/dev/null || true
    return 1
  fi
}

# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

flash_confirmation() {
  local window="$1"
  local i

  for ((i=0; i < FLASH_COUNT; i++)); do
    tmux set-option -t "$window" status-style "bg=#ff0055,fg=#ffffff" 2>/dev/null || true
    sleep "$FLASH_DURATION"
    tmux set-option -t "$window" status-style "default" 2>/dev/null || true
    sleep "$FLASH_DURATION"
  done
}

# ============================================================================
# ENTRY POINT
# ============================================================================

main "$@"
