#!/bin/bash
# tmux-link-grab - URL seeking for tmux

tmux capture-pane -pJ -S-100 2>/dev/null | \
  grep -oE 'https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^[:space:]>"'\'')<]*' | \
  awk '!seen[$0]++' | \
  tac | \
  fzf --height=40% --reverse --header='↵ copy' | \
  tr -d '\n' | \
  pbcopy && tmux display-message "✓ copied"
