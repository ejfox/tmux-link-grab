# tmux-link-grab

Fast URL seeking for tmux with fzf. `prefix + s` → pick URL → open in browser.

## Features

- **Flexible scope** - search current pane, window, session, or history
- **Pane labels** - see which pane each URL came from (e.g. `[nvim] https://...`)
- **Persistent history** - access previously opened URLs even after scrollback is gone
- **Proper tmux citizen** - configure via tmux options, respects your copy-command
- **fzf interface** - j/k navigation, fuzzy search

## Install

### TPM (recommended)

```tmux
set -g @plugin 'ejfox/tmux-link-grab'
```

Then `prefix + I` to install. Keybinding is set up automatically.

### Manual

```bash
git clone https://github.com/ejfox/tmux-link-grab ~/.tmux/plugins/tmux-link-grab
```

Add to `.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-link-grab/plugin.tmux
```

## Config

All options go in your `.tmux.conf` **before** the plugin line:

```tmux
# Key binding (default: s)
set -g @link-grab-key "s"

# Scope: "pane", "window", "session", or "history" (default: window)
set -g @link-grab-scope "window"

# Action: "open", "copy", or "buffer" (default: open)
set -g @link-grab-action "open"

# Show pane labels (default: true)
set -g @link-grab-labels "true"

# Scrollback lines to search (default: 200)
set -g @link-grab-lines "200"

# History file (default: ~/.tmux-link-history, set "" to disable)
set -g @link-grab-history "$HOME/.tmux-link-history"
set -g @link-grab-history-max "100"

# Load plugin
set -g @plugin 'ejfox/tmux-link-grab'
```

## Actions

| Action | Behavior |
|--------|----------|
| `open` | Open URL in browser |
| `copy` | Copy to system clipboard (respects your `copy-command`) |
| `buffer` | Save to tmux paste buffer (`prefix + ]` to paste) |

## Keys

| Key | Action |
|-----|--------|
| Enter | Execute action |
| Space | Execute action |
| j/k | Navigate |
| Esc | Cancel |

## Feedback

Actions show confirmation in tmux status line:
- `Opened: github.com`
- `Copied: https://example.com/path...`
- `Saved to tmux buffer`
- `No URLs found`

## Requirements

- tmux 3.0+ (for display-popup)
- fzf
- `open` (macOS) or `xdg-open` (Linux)

## License

GNU GPL v3
