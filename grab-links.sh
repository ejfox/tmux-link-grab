#!/bin/bash
# ============================================================================
# tmux-link-grab - URL seeking for tmux
# prefix + s → fzf URLs, enter to open, j/k to navigate
# ============================================================================

# ============================================================================
# CONFIG
# ============================================================================

# Scope: "pane" (current pane only) or "window" (all panes, current first)
SCOPE="window"

# How many lines of scrollback to search per pane
SCROLLBACK_LINES=200

# Action: "open" or "copy"
ACTION="open"

# ============================================================================

URL_PATTERN='https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^[:space:]>"'\'')<]*|https?://localhost(:[0-9]+)?[^[:space:]>"'\'')<]*'

extract_urls() {
    tmux capture-pane -p -t "$1" -S-"$SCROLLBACK_LINES" 2>/dev/null | grep -oE "$URL_PATTERN"
}

if [ "$SCOPE" = "window" ]; then
    CURRENT_PANE=$(tmux display-message -p '#{pane_id}')
    {
        extract_urls "$CURRENT_PANE" | awk '!seen[$0]++' | tac
        for pane in $(tmux list-panes -F '#{pane_id}'); do
            [ "$pane" != "$CURRENT_PANE" ] && extract_urls "$pane" | awk '!seen[$0]++' | tac
        done
    } | grep -v '^$' | awk '!seen[$0]++'
else
    tmux capture-pane -pJ -S-"$SCROLLBACK_LINES" 2>/dev/null | grep -oE "$URL_PATTERN" | awk '!seen[$0]++' | tac
fi | fzf --no-info --no-sort --disabled --reverse --bind 'j:down,k:up,space:accept' --color 'pointer:red' | {
    read -r URL
    [ -n "$URL" ] && { [ "$ACTION" = "copy" ] && echo -n "$URL" | pbcopy || open "$URL"; }
}
