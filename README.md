# tmux-link-grab

Fast URL/IP seeking for tmux. `prefix + s` → fzf → Enter=copy, Space=open.

## What it grabs

- `https://`, `http://`, `ftp://` URLs
- `localhost:3000`
- `192.168.1.1:8080`
- IPv4 addresses with optional ports

## Install

### TPM (Recommended)

Add to your `~/.tmux.conf`:

```tmux
set -g @plugin 'ejfox/tmux-link-grab'
```

Then press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/ejfox/tmux-link-grab ~/.tmux/plugins/tmux-link-grab
```

Add to your `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-link-grab/plugin.tmux
```

Then reload tmux configuration:

```bash
tmux source-file ~/.tmux.conf
```

## Usage

Press `prefix + s` (default) to open the link grabber. Use fzf to navigate:

| Key | Action |
|-----|--------|
| ↑/↓ | Navigate links |
| Enter | Copy to clipboard |
| Space | Open in browser |
| Esc | Cancel |

## Configuration

Add these options to your `~/.tmux.conf` before the plugin declaration:

```tmux
# Change the key binding (default: 's')
set -g @link-grab-key 'u'

# Number of scrollback lines to search (default: 200)
set -g @link-grab-lines 500

# Browser command (default: $BROWSER or xdg-open)
set -g @link-grab-browser 'firefox'
```

### Example Configuration

```tmux
# Customize tmux-link-grab
set -g @link-grab-key 'u'
set -g @link-grab-lines 1000
set -g @link-grab-browser 'chromium'

# Load plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'ejfox/tmux-link-grab'

# Initialize TPM (keep at bottom)
run '~/.tmux/plugins/tpm/tpm'
```

## Dependencies

- **fzf** - Required for interactive selection
- **Clipboard tool** (one of):
  - `pbcopy` (macOS - built-in)
  - `xclip` (Linux X11)
  - `wl-copy` (Linux Wayland)
  - Falls back to tmux buffer if none available

## Troubleshooting

### "fzf is not installed"

Install fzf:
- macOS: `brew install fzf`
- Debian/Ubuntu: `apt install fzf`
- Fedora: `dnf install fzf`

### "no clipboard tool found"

Install a clipboard utility:
- Linux X11: `apt install xclip` or `dnf install xclip`
- Linux Wayland: `apt install wl-clipboard` or `dnf install wl-clipboard`

The plugin will still work with tmux's internal buffer if no system clipboard is available.

### Key binding doesn't work

Make sure you reload your tmux configuration after installation:
```bash
tmux source-file ~/.tmux.conf
```

Or restart tmux entirely.

## License

GNU GPL v3
