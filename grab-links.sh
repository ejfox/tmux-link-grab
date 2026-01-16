#!/bin/bash
# ============================================================================
# tmux-link-grab - URL seeking for tmux
# prefix + s → fzf URLs, enter to open, j/k to navigate
# ============================================================================

# ============================================================================
# CONFIG
# ============================================================================

# Scope: "pane", "window", "session", or "history"
SCOPE="window"

# How many lines of scrollback to search per pane
SCROLLBACK_LINES=200

# Action: "open" or "copy"
ACTION="open"

# Show pane labels in window/session mode: true or false
SHOW_LABELS=true

# History file (set to "" to disable)
HISTORY_FILE="$HOME/.tmux-link-history"
HISTORY_MAX=100

# ============================================================================

URL_PATTERN='https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^[:space:]>"'\'')<]*|https?://localhost(:[0-9]+)?[^[:space:]>"'\'')<]*'

get_pane_label() {
    tmux display-message -t "$1" -p '#{pane_current_command}' 2>/dev/null | head -c 12
}

extract_urls() {
    local pane="$1"
    local label="$2"
    if [ -n "$label" ] && [ "$SHOW_LABELS" = true ]; then
        tmux capture-pane -p -t "$pane" -S-"$SCROLLBACK_LINES" 2>/dev/null | \
            grep -oE "$URL_PATTERN" | while read -r url; do echo "[$label] $url"; done
    else
        tmux capture-pane -p -t "$pane" -S-"$SCROLLBACK_LINES" 2>/dev/null | grep -oE "$URL_PATTERN"
    fi
}

save_to_history() {
    [ -z "$HISTORY_FILE" ] && return
    local url="$1"
    echo "$(date +%s) $url" >> "$HISTORY_FILE"
    # Trim history if too long
    if [ -f "$HISTORY_FILE" ] && [ "$(wc -l < "$HISTORY_FILE")" -gt "$HISTORY_MAX" ]; then
        tail -n "$HISTORY_MAX" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
}

show_history() {
    [ -z "$HISTORY_FILE" ] || [ ! -f "$HISTORY_FILE" ] && echo "No history" && return
    tac "$HISTORY_FILE" | awk '!seen[$2]++ {print $2}'
}

CURRENT_PANE=$(tmux display-message -p '#{pane_id}')
CURRENT_LABEL=$(get_pane_label "$CURRENT_PANE")

case "$SCOPE" in
    history)
        show_history
        ;;
    session)
        {
            extract_urls "$CURRENT_PANE" "" | awk '!seen[$0]++' | tac
            for pane in $(tmux list-panes -a -F '#{pane_id}'); do
                if [ "$pane" != "$CURRENT_PANE" ]; then
                    label=$(get_pane_label "$pane")
                    extract_urls "$pane" "$label" | awk '!seen[$0]++' | tac
                fi
            done
        } | grep -v '^$' | awk '!seen[$0]++'
        ;;
    window)
        {
            extract_urls "$CURRENT_PANE" "" | awk '!seen[$0]++' | tac
            for pane in $(tmux list-panes -F '#{pane_id}'); do
                if [ "$pane" != "$CURRENT_PANE" ]; then
                    label=$(get_pane_label "$pane")
                    extract_urls "$pane" "$label" | awk '!seen[$0]++' | tac
                fi
            done
        } | grep -v '^$' | awk '!seen[$0]++'
        ;;
    *)
        tmux capture-pane -pJ -S-"$SCROLLBACK_LINES" 2>/dev/null | grep -oE "$URL_PATTERN" | awk '!seen[$0]++' | tac
        ;;
esac | fzf --no-info --no-sort --disabled --reverse --bind 'j:down,k:up,space:accept' --color 'pointer:red' | {
    read -r LINE
    [ -z "$LINE" ] && exit 0
    # Strip label if present
    URL=$(echo "$LINE" | sed 's/^\[[^]]*\] //')
    [ -n "$URL" ] && {
        save_to_history "$URL"
        [ "$ACTION" = "copy" ] && echo -n "$URL" | pbcopy || open "$URL"
    }
}
