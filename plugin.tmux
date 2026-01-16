#!/usr/bin/env bash
# tmux-link-grab plugin initialization

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get user's preferred key or default to 's'
get_opt() {
    local opt="$1" default="$2"
    local val=$(tmux show-option -gqv "$opt")
    echo "${val:-$default}"
}

KEY=$(get_opt "@link-grab-key" "s")

# Bind the key to launch grab-links in a popup
tmux bind-key "$KEY" display-popup -E "$CURRENT_DIR/grab-links.sh"
