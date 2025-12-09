# tmux-link-grab

Elegant seek-mode for URLs and IPs in tmux. Hit `prefix + s`, numbered list appears, type the number, it flashes confirmation and copies to clipboard.

## Features

- **Zero friction**: One keybinding to access all URLs and IPs
- **Smart extraction**: Finds `https://`, `http://`, `ftp://` URLs and IPv4 addresses
- **Fast selection**: Number-based picking (like vim's `s` or neovim's `leap.nvim`)
- **Visual feedback**: Status bar flashes on successful copy
- **Cross-platform**: Works on macOS (pbcopy), Linux (xclip/wl-copy)
- **Bulletproof**: Full error handling, dependency checks, graceful degradation
- **Window-wide**: Searches entire window (all panes at once)
- **Scrollback aware**: Searches last 100 lines (configurable)
- **Idempotent**: Safe to call repeatedly without side effects

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
bind-key s display-popup -E "~/.tmux/plugins/tmux-link-grab/grab-links.sh"
```

Reload: `tmux source-file ~/.tmux.conf`

## Usage

1. Press `prefix + s` (or whatever key you bind)
2. Numbered list of URLs and IPs appear in fzf
3. Type the number to select (or arrow keys + enter)
4. **Flash** — status bar blinks confirmation
5. URL copied to clipboard, back to normal

### Keyboard shortcuts in fzf menu

- **Enter** - Copy selected URL
- **Esc** - Cancel (return without copying)
- **Arrow keys** - Navigate
- **Type** - Filter/search

## Configuration

Edit the top of `grab-links.sh` to customize:

```bash
SCROLLBACK_LINES=100    # Lines to search back through
FLASH_COUNT=2           # Number of flashes on copy
FLASH_DURATION=0.1      # Duration of each flash (seconds)
```

## Supported Patterns

**URLs:**
- `https://example.com/path?query=value#fragment`
- `http://example.com`
- `ftp://example.com`

**Network:**
- `192.168.1.1`
- `10.0.0.1:8080`

## Requirements

- **tmux** (1.9+)
- **fzf** - for the selection menu
- **grep** - URL/IP extraction
- **One of**: `pbcopy` (macOS), `xclip` (Linux X11), or `wl-copy` (Linux Wayland)

Missing dependencies will be caught and reported with a clear error message.

## Error Handling

The plugin includes:
- Dependency validation (checks for required tools at runtime)
- Graceful error messages if dependencies are missing
- Cross-platform clipboard detection
- Empty scrollback handling
- User cancellation support (esc key)
- Safe piping with `set -euo pipefail`

## Troubleshooting

### "No URLs or IPs found"
- Make sure there are URLs/IPs in the current window's scrollback
- Try scrolling up to add more history

### "Missing dependencies"
- **macOS**: Should work out of the box with `pbcopy`
- **Linux**: Install `fzf` and either `xclip` or `wl-copy`:
  - Ubuntu/Debian: `sudo apt install fzf xclip`
  - Fedora: `sudo dnf install fzf xclip`
  - Wayland: `sudo apt install fzf wl-clipboard`

### Clipboard not working
- Verify your clipboard tool is installed: `which pbcopy` or `which xclip`
- For SSH sessions, use `pbcopy` forwarding or remote clipboard tools

## Performance

- Negligible overhead - works even in large scrollbacks
- Uses efficient `grep` patterns for extraction
- Non-blocking UI (fzf is highly optimized)

## License

GNU General Public License v3 — see LICENSE file

## Contributing

Found a bug or want a feature? Open an issue or PR on [GitHub](https://github.com/ejfox/tmux-link-grab).
