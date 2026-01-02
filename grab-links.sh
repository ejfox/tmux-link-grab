#!/bin/bash
# tmux-link-grab - fast URL/IP seeking for tmux
# prefix+s → fzf → Enter=copy, Space=open
# License: GNU GPL v3

set -uo pipefail

LINES=${TMUX_LINK_GRAB_LINES:-200}

# Clipboard detection
clip() {
  command -v pbcopy &>/dev/null && echo "pbcopy" && return
  command -v xclip &>/dev/null && echo "xclip -selection clipboard" && return
  command -v wl-copy &>/dev/null && echo "wl-copy" && return
  return 1
}

main() {
  CLIPBOARD=$(clip) || { tmux display-message "No clipboard tool"; exit 1; }
  command -v fzf &>/dev/null || { tmux display-message "fzf required"; exit 1; }

  # Single capture, single grep - fast
  items=$(tmux capture-pane -p -J -S "-$LINES" 2>/dev/null | \
    grep -oE '(https?|ftp)://[^[:space:]]+|localhost:[0-9]+|([0-9]{1,3}\.){3}[0-9]{1,3}(:[0-9]+)?' | \
    sed 's/[)>,.";"'\''":]*$//' | \
    awk '!x[$0]++' | \
    tac) || true

  [ -z "$items" ] && { tmux display-message "Nothing found"; exit 0; }

  result=$(printf '%s\n' "$items" | \
    fzf --height=40% --reverse \
        --header='↵ copy │ ␣ open' \
        --expect=enter,space \
        --color='hl:196') || exit 0

  key=$(head -1 <<< "$result")
  item=$(tail -1 <<< "$result")
  [ -z "$item" ] && exit 0

  case "$key" in
    space)
      if [[ "$item" =~ ^(localhost|[0-9]+\.) ]]; then
        open "http://$item" 2>/dev/null || xdg-open "http://$item" 2>/dev/null
      else
        open "$item" 2>/dev/null || xdg-open "$item" 2>/dev/null
      fi
      tmux display-message "◆ $item"
      ;;
    *)
      printf '%s' "$item" | $CLIPBOARD && tmux display-message "✓ $item"
      ;;
  esac
}

main
