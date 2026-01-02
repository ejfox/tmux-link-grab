# tmux-link-grab

Fast URL/IP seeking for tmux. `prefix + s` → fzf → Enter=copy, Space=open.

## What it grabs

- `https://`, `http://`, `ftp://` URLs
- `localhost:3000`
- `192.168.1.1:8080`

## Install

### TPM

```tmux
set -g @plugin 'ejfox/tmux-link-grab'
```

`prefix + I` to install.

### Manual

```bash
git clone https://github.com/ejfox/tmux-link-grab ~/.tmux/plugins/tmux-link-grab
```

```tmux
bind-key s display-popup -E "~/.tmux/plugins/tmux-link-grab/grab-links.sh"
```

## Keys

| Key | Action |
|-----|--------|
| Enter | Copy to clipboard |
| Space | Open in browser |
| Esc | Cancel |

## Config

```bash
export TMUX_LINK_GRAB_LINES=500  # default: 200
```

## License

GNU GPL v3
