# tmux-link-grab

Fast URL seeking for tmux with fzf. `prefix + s` → pick URL → open in browser.

## Features

- **Flexible scope** - search current pane, window, session, or history
- **Pane labels** - see which pane each URL came from (e.g. `[nvim] https://...`)
- **Persistent history** - access previously opened URLs even after scrollback is gone
- **fzf interface** - j/k navigation, fuzzy search
- **Deduped & sorted** - most recent URLs first, no duplicates

## Install

### TPM (recommended)

```tmux
set -g @plugin 'ejfox/tmux-link-grab'
```

Then `prefix + I` to install.

### Manual

```bash
git clone https://github.com/ejfox/tmux-link-grab ~/.tmux/plugins/tmux-link-grab
```

Add to `.tmux.conf`:

```tmux
bind-key s display-popup -E "~/.tmux/plugins/tmux-link-grab/grab-links.sh"
```

## Config

Edit the top of `grab-links.sh`:

```bash
# Scope: "pane", "window", "session", or "history"
SCOPE="window"

# How many lines of scrollback to search per pane
SCROLLBACK_LINES=200

# Action: "open" or "copy"
ACTION="open"

# Show pane labels in window/session mode
SHOW_LABELS=true

# History file (set to "" to disable)
HISTORY_FILE="$HOME/.tmux-link-history"
HISTORY_MAX=100
```

## Keys

| Key | Action |
|-----|--------|
| Enter | Execute action (open or copy) |
| Space | Execute action |
| j/k | Navigate |
| Esc | Cancel |

## What it grabs

- `https://example.com/path`
- `http://localhost:3000`

## Requirements

- tmux
- fzf
- `open` (macOS) or `xdg-open` (Linux)
- `pbcopy` (macOS) or `xclip`/`wl-copy` (Linux) for copy action

## License

GNU GPL v3
