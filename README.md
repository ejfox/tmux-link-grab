# tmux-link-grab

Elegant seek-mode for URLs and IPs in tmux. Hit `prefix + s`, numbers light up on every URL/IP in your scrollback, type the number, it flashes confirmation and copies to clipboard.

## Install

### With TPM (recommended)

Add to `~/.tmux.conf`:
```tmux
set -g @plugin 'ejfox/tmux-link-grab'
bind-key s run-shell "~/.tmux/plugins/tmux-link-grab/grab-links.sh"
```

Then in tmux: `prefix + I` to install.

### Manual

```bash
git clone https://github.com/ejfox/tmux-link-grab ~/.tmux/plugins/tmux-link-grab
```

Add to `~/.tmux.conf`:
```tmux
bind-key s run-shell "~/.tmux/plugins/tmux-link-grab/grab-links.sh"
```

Reload: `tmux source-file ~/.tmux.conf`

## Usage

1. Press `prefix + s` (or whatever key you bind)
2. Numbered list of URLs and IPs appear
3. Type the number to select
4. **Flash** — status bar blinks confirmation
5. URL copied to clipboard, back to normal

## Features

- Extracts URLs (`https://`, `http://`, `ftp://`) and IPv4 addresses
- Shows all unique matches from last 100 lines of scrollback
- Number-based selection (just like vim's `s` or neovim's `leap.nvim`)
- Visual flash confirmation
- Instant clipboard copy

## Requirements

- `fzf` - for the selection menu
- `grep` - URL extraction
- `pbcopy` (macOS) or `xclip`/`wl-copy` (Linux)

## License

GNU General Public License v3 — see LICENSE file
