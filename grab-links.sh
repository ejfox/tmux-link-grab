#!/bin/bash

# tmux-link-grab - elegant URL/IP/path seeking for tmux
# Hit prefix+s, fzf list appears, Enter to copy, Space to open
# License: GNU GPL v3

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCROLLBACK_LINES=${TMUX_LINK_GRAB_LINES:-500}

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

  for cmd in tmux fzf; do
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
# EXTRACTION PATTERNS
# ============================================================================

extract_items() {
  local content="$1"

  # URLs (http/https/ftp) - clean trailing punctuation
  echo "$content" | grep -oE '(https?|ftp)://[^ ]+' | sed 's/[)>,."'\''";:]+$//' | sed 's/[)>,."'\''";:]$//'

  # IPs with optional port
  echo "$content" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}(:[0-9]+)?'

  # localhost with port
  echo "$content" | grep -oE 'localhost:[0-9]+'

  # File paths (absolute and ~/)
  echo "$content" | grep -oE '(~|/)[a-zA-Z0-9_./-]+\.[a-zA-Z0-9]+' | grep -v '^/[0-9]'

  # Git commit hashes (7-40 hex chars, standalone)
  echo "$content" | grep -oE '\b[0-9a-f]{7,40}\b' | grep -v '[g-z]'
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

main() {
  # Check all dependencies exist
  if ! check_dependencies; then
    tmux display-message "tmux-link-grab: Missing dependencies" 2>/dev/null || exit 1
  fi

  # Capture from ALL panes in current window
  local content=""
  local panes
  panes=$(tmux list-panes -F '#{pane_id}')

  for pane in $panes; do
    content+=$(tmux capture-pane -p -J -S "-${SCROLLBACK_LINES}" -t "$pane" 2>/dev/null || true)
    content+=$'\n'
  done

  # Extract all item types
  local items
  items=$(extract_items "$content" | awk '!seen[$0]++' | tac)

  if [ -z "$items" ]; then
    tmux display-message "tmux-link-grab: Nothing found" 2>/dev/null || true
    return 1
  fi

  # Count items for header
  local count
  count=$(echo "$items" | wc -l | tr -d ' ')

  # Let user pick using fzf
  local result
  result=$(echo "$items" | \
    fzf --no-preview \
      --height 50% \
      --header "↵ copy │ ␣ open │ ${count} items" \
      --expect 'enter,space' \
      --bind 'esc:abort' \
      --color 'hl:196,hl+:196')

  if [ -z "$result" ]; then
    return 0
  fi

  # Parse fzf output
  local key=$(echo "$result" | head -1)
  local item=$(echo "$result" | tail -1)

  if [ -z "$item" ]; then
    return 0
  fi

  case "$key" in
    space)
      # Open in browser/finder
      if [[ "$item" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        open "http://$item" 2>/dev/null || xdg-open "http://$item" 2>/dev/null
      elif [[ "$item" =~ ^localhost: ]]; then
        open "http://$item" 2>/dev/null || xdg-open "http://$item" 2>/dev/null
      elif [[ "$item" =~ ^[~/] ]]; then
        # Expand ~ and open in finder/file manager
        local expanded="${item/#\~/$HOME}"
        if [ -e "$expanded" ]; then
          open "$expanded" 2>/dev/null || xdg-open "$expanded" 2>/dev/null
        else
          tmux display-message "✗ Not found: $item"
          return 1
        fi
      else
        open "$item" 2>/dev/null || xdg-open "$item" 2>/dev/null
      fi
      tmux display-message "◆ Opening: $item"
      ;;
    *)
      # Default (enter): copy to clipboard
      if echo -n "$item" | $CLIPBOARD 2>/dev/null; then
        tmux display-message "✓ Copied: $item"
      else
        tmux display-message "✗ Failed to copy" 2>/dev/null || true
        return 1
      fi
      ;;
  esac
}

# ============================================================================
# ENTRY POINT
# ============================================================================

main "$@"
