#!/bin/bash

# Get current pane
PANE="${1:-.}"

# Grab URLs from scrollback (last 100 lines)
URLS=$(tmux capture-pane -p -S -100 -t "$PANE" | grep -oE 'https?://[^\s]+|ftp://[^\s]+' | sort -u)

if [ -z "$URLS" ]; then
  tmux display-message "No URLs found"
  exit 1
fi

# Number them and let user pick
SELECTED=$(echo "$URLS" | nl -w1 -s'. ' | fzf --no-preview --bind 'enter:accept')

if [ -n "$SELECTED" ]; then
  # Extract URL (remove the number)
  URL=$(echo "$SELECTED" | sed 's/^[0-9]*\. //')

  # Copy to clipboard
  echo -n "$URL" | pbcopy

  tmux display-message "Copied: $URL"
fi
