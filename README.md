# tmux-link-grab

Seek-mode for URLs, IPs, file paths, and git hashes in tmux. `prefix + s` → fzf list → Enter to copy, Space to open.

## What it grabs

- **URLs** - `https://`, `http://`, `ftp://` (cleans trailing punctuation)
- **IPs** - `192.168.1.1`, `10.0.0.1:8080`
- **localhost** - `localhost:3000`
- **File paths** - `~/foo.txt`, `/usr/bin/bash`
- **Git hashes** - 7-40 char commit SHAs

## Features

- **All panes** - Searches entire window (all panes at once)
- **Most recent first** - Enter immediately copies the newest item
- **Smart open** - Space opens URLs in browser, files in Finder
- **500 lines** - Configurable scrollback depth
- **Cross-platform** - macOS (pbcopy), Linux (xclip/wl-copy)

## Install

### TPM

```tmux
set -g @plugin 'ejfox/tmux-link-grab'
```

Then `prefix + I` to install.

### Manual

```bash
git clone https://github.com/ejfox/tmux-link-grab ~/.tmux/plugins/tmux-link-grab
```

Add to `~/.tmux.conf`:

```tmux
bind-key s display-popup -E "~/.tmux/plugins/tmux-link-grab/grab-links.sh"
```

## Usage

| Key | Action |
|-----|--------|
| `prefix + s` | Open seek mode |
| `Enter` | Copy to clipboard |
| `Space` | Open (browser/finder) |
| `Esc` | Cancel |

## Config

Set scrollback depth (default 500):

```bash
export TMUX_LINK_GRAB_LINES=1000
```

## License

GNU GPL v3
