#!/bin/bash
# ============================================================================
# tmux-link-grab - URL seeking for tmux
# ============================================================================

# ============================================================================
# Read tmux options (with defaults)
# ============================================================================

get_opt() {
    local opt="$1" default="$2"
    local val=$(tmux show-option -gqv "$opt")
    echo "${val:-$default}"
}

SCOPE=$(get_opt "@link-grab-scope" "window")
SCROLLBACK=$(get_opt "@link-grab-lines" "200")
ACTION=$(get_opt "@link-grab-action" "open")
SHOW_LABELS=$(get_opt "@link-grab-labels" "true")
HISTORY_FILE=$(get_opt "@link-grab-history" "$HOME/.tmux-link-history")
HISTORY_MAX=$(get_opt "@link-grab-history-max" "100")

# ============================================================================
# Core functions
# ============================================================================

URL_PATTERN='https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^[:space:]>"'\'')<]*|https?://localhost(:[0-9]+)?[^[:space:]>"'\'')<]*'

get_pane_label() {
    tmux display-message -t "$1" -p '#{pane_current_command}' 2>/dev/null | head -c 12
}

extract_urls() {
    local pane="$1" label="$2"
    local content=$(tmux capture-pane -p -t "$pane" -S-"$SCROLLBACK" 2>/dev/null)
    if [ -n "$label" ] && [ "$SHOW_LABELS" = "true" ]; then
        echo "$content" | grep -oE "$URL_PATTERN" | while read -r url; do echo "[$label] $url"; done
    else
        echo "$content" | grep -oE "$URL_PATTERN"
    fi
}

save_history() {
    [ -z "$HISTORY_FILE" ] && return
    echo "$(date +%s) $1" >> "$HISTORY_FILE"
    if [ -f "$HISTORY_FILE" ] && [ "$(wc -l < "$HISTORY_FILE")" -gt "$HISTORY_MAX" ]; then
        tail -n "$HISTORY_MAX" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
}

show_history() {
    [ -z "$HISTORY_FILE" ] || [ ! -f "$HISTORY_FILE" ] && return
    tac "$HISTORY_FILE" | awk '!seen[$2]++ {print $2}'
}

copy_url() {
    local url="$1"
    # Check for user's copy-command first
    local copy_cmd=$(tmux show-option -gqv "copy-command")
    if [ -n "$copy_cmd" ]; then
        echo -n "$url" | eval "$copy_cmd"
    elif command -v pbcopy &>/dev/null; then
        echo -n "$url" | pbcopy
    elif command -v xclip &>/dev/null; then
        echo -n "$url" | xclip -selection clipboard
    elif command -v wl-copy &>/dev/null; then
        echo -n "$url" | wl-copy
    else
        # Fallback: tmux buffer
        tmux set-buffer "$url"
        tmux display-message "Copied to tmux buffer (prefix+] to paste)"
        return
    fi
    tmux display-message "Copied: ${url:0:50}..."
}

open_url() {
    local url="$1"
    if command -v open &>/dev/null; then
        open "$url"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url"
    else
        tmux display-message "No browser found"
        return 1
    fi
    # Extract domain for display
    local domain=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|' | head -c 40)
    tmux display-message "Opened: $domain"
}

# ============================================================================
# Gather URLs based on scope
# ============================================================================

CURRENT_PANE=$(tmux display-message -p '#{pane_id}')

gather_urls() {
    case "$SCOPE" in
        history)
            show_history
            ;;
        session)
            {
                extract_urls "$CURRENT_PANE" "" | awk '!seen[$0]++' | tac
                for pane in $(tmux list-panes -a -F '#{pane_id}'); do
                    [ "$pane" != "$CURRENT_PANE" ] && extract_urls "$pane" "$(get_pane_label "$pane")" | awk '!seen[$0]++' | tac
                done
            } | grep -v '^$' | awk '!seen[$0]++'
            ;;
        window)
            {
                extract_urls "$CURRENT_PANE" "" | awk '!seen[$0]++' | tac
                for pane in $(tmux list-panes -F '#{pane_id}'); do
                    [ "$pane" != "$CURRENT_PANE" ] && extract_urls "$pane" "$(get_pane_label "$pane")" | awk '!seen[$0]++' | tac
                done
            } | grep -v '^$' | awk '!seen[$0]++'
            ;;
        *)
            tmux capture-pane -pJ -S-"$SCROLLBACK" 2>/dev/null | grep -oE "$URL_PATTERN" | awk '!seen[$0]++' | tac
            ;;
    esac
}

# ============================================================================
# Main
# ============================================================================

URLS=$(gather_urls)

if [ -z "$URLS" ]; then
    tmux display-message "No URLs found"
    exit 0
fi

SELECTED=$(echo "$URLS" | fzf --no-info --no-sort --disabled --reverse \
    --bind 'j:down,k:up,space:accept' \
    --color 'pointer:red')

[ -z "$SELECTED" ] && exit 0

# Strip label if present
URL=$(echo "$SELECTED" | sed 's/^\[[^]]*\] //')

# Save to history
[ -n "$HISTORY_FILE" ] && save_history "$URL"

# Execute action
case "$ACTION" in
    copy) copy_url "$URL" ;;
    buffer) tmux set-buffer "$URL" && tmux display-message "Saved to tmux buffer" ;;
    *) open_url "$URL" ;;
esac
