# tmux-link-grab

Dead simple tmux plugin. Hit a key, see all URLs numbered, pick one, boom—copied.

## Install

### With TPM (recommended)

Add to `~/.tmux.conf`:
```tmux
set -g @plugin 'ejfox/tmux-link-grab'
bind-key U run-shell "~/.tmux/plugins/tmux-link-grab/grab-links.sh"
```

Then in tmux: `prefix + I` to install.

### Manual

```bash
git clone https://github.com/ejfox/tmux-link-grab ~/.tmux/plugins/tmux-link-grab
```

Add to `~/.tmux.conf`:
```tmux
bind-key U run-shell "~/.tmux/plugins/tmux-link-grab/grab-links.sh"
```

## Usage

1. Press `prefix + U`
2. See all URLs from scrollback (last 100 lines) numbered
3. Type the number → enter
4. URL copied to clipboard

## Requirements

- `fzf` - for the selection menu
- `grep` - URL extraction
- `pbcopy` (macOS) or `xclip`/`wl-copy` (Linux)

## License

MIT
