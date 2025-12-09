#!/bin/bash

# tmux-link-grab - elegant URL/IP seeking for tmux
# Hit prefix+s, numbers appear on URLs, type number, get highlighted flash of confirmation

PANE="${1:-.}"

# Extract URLs and IPs from last 100 lines of scrollback
URLS=$(tmux capture-pane -p -S -100 -t "$PANE" | \
  grep -oE 'https?://[^\s]+|ftp://[^\s]+|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
  sort -u)

if [ -z "$URLS" ]; then
  tmux display-message "No URLs or IPs found"
  exit 1
fi

# Create numbered list with colors
NUMBERED=$(echo "$URLS" | nl -w1 -s' ' | awk '{print "\033[38;5;196m" $1 "\033[0m " $2}')

# Show in popup with live preview
CHOICE=$(echo "$URLS" | nl -w1 -s'. ' | \
  fzf --ansi \
    --no-preview \
    --height 50% \
    --bind 'enter:accept' \
    --color 'hl:196' \
    --preview 'echo "Hit enter to copy"' \
    --preview-window 'bottom:2' \
  2>/dev/null)

if [ -z "$CHOICE" ]; then
  exit 0
fi

# Extract URL from choice
URL=$(echo "$CHOICE" | sed 's/^[0-9]*\. //')

# Copy to clipboard
echo -n "$URL" | pbcopy

# Flash confirmation - blink the status bar
tmux set-option -t "$PANE" status-style "bg=#ff0055,fg=#ffffff" 2>/dev/null
sleep 0.1
tmux set-option -t "$PANE" status-style "default" 2>/dev/null
sleep 0.1
tmux set-option -t "$PANE" status-style "bg=#ff0055,fg=#ffffff" 2>/dev/null
sleep 0.1
tmux set-option -t "$PANE" status-style "default" 2>/dev/null

tmux display-message "Copied: $URL"
