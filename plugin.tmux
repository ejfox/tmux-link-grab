#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default key binding
default_key="s"
tmux_link_grab_key=$(tmux show-option -gqv "@link-grab-key")
tmux_link_grab_key=${tmux_link_grab_key:-$default_key}

# Set up key binding
tmux bind-key "$tmux_link_grab_key" display-popup -E -w 80% -h 80% "$CURRENT_DIR/grab-links.sh"
