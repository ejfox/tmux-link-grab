#!/bin/bash
# tmux-link-grab - instant URL seeking
# License: GNU GPL v3

# Reduced scrollback = faster capture
N=${TMUX_LINK_GRAB_LINES:-50}

# Cache clipboard on first run
[[ -z "${CLIP:-}" ]] && {
  command -v pbcopy &>/dev/null && CLIP=pbcopy
  command -v xclip &>/dev/null && CLIP="xclip -sel clip"
  command -v wl-copy &>/dev/null && CLIP=wl-copy
}
[[ -z "${CLIP:-}" ]] && exit 1

# Single pipeline: capture → extract → dedupe → fzf (with --tac for newest-first)
result=$(tmux capture-pane -pJ -S-$N 2>/dev/null | \
  grep -oE 'https?://[^[:space:]>"'\'')]+|localhost:[0-9]+|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?' | \
  awk '!s[$0]++' | \
  fzf --tac --no-sort --height=40% --reverse --expect=enter,space --header='↵cp ␣open' --color=hl:196) || exit 0

# Parse result
key=${result%%$'\n'*}
item=${result##*$'\n'}
[[ -z "$item" ]] && exit 0

# Action
case "$key" in
  space)
    [[ "$item" =~ ^https?: ]] || item="http://$item"
    open "$item" 2>/dev/null || xdg-open "$item" 2>/dev/null
    ;;
  *) printf '%s' "$item" | $CLIP && tmux display-message "✓ $item" ;;
esac
