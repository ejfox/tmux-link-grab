#!/bin/bash
# ============================================================================
# tmux-link-grab - URL seeking for tmux
# ============================================================================

# -e is deliberately omitted: grep -oE returns 1 on "no matches" which is
# a normal case (no URLs on screen), not an error worth aborting on.
set -uo pipefail

# ============================================================================
# Read tmux options (with defaults)
# ============================================================================

get_opt() {
    local opt="$1" default="$2"
    local val
    val=$(tmux show-option -gqv "$opt")
    echo "${val:-$default}"
}

SCOPE=$(get_opt "@link-grab-scope" "window")
SCROLLBACK=$(get_opt "@link-grab-lines" "200")
ACTION=$(get_opt "@link-grab-action" "open")
SHOW_LABELS=$(get_opt "@link-grab-labels" "true")
HISTORY_FILE=$(get_opt "@link-grab-history" "$HOME/.tmux-link-history")
HISTORY_MAX=$(get_opt "@link-grab-history-max" "100")

# ============================================================================
# Core functions
# ============================================================================

# Detection is two-stage. URL_PATTERN is deliberately greedy: it grabs
# anything that *might* be a URL up to whitespace, quotes, angle brackets
# or backticks:
#   1. scheme URLs          https://…  http://…
#   2. git remotes          git@host:owner/repo  [git+]ssh://git@host/owner/repo
#   3. bare hosts           github.com/x  localhost:3000  github.com:a/b.git
#      — only at line start or after whitespace, an opening bracket, a
#      quote, backtick, * | = or , so we never start mid-path
#      (/Applications/Foo.app) or mid-email (a@b.com). The leading
#      delimiter is part of the match; clean_urls drops it. A trailing
#      "(" or "@" is captured too, so clean_urls can reject method calls
#      (arr.at(-1)) and email local parts (first.me@gmail.com).
# clean_urls then trims the edges and rejects junk — things a single ERE
# can't express, like balanced parens or "is this a real TLD".
URL_PATTERN='https?://[^[:space:]<>"'\''`]+|((git\+)?ssh://)?git@[a-zA-Z0-9.-]+[:/][^[:space:]<>"'\''`]+|(^|[[:space:]([{<"'\''`*|=,])([a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]+|localhost)(:[a-zA-Z0-9_.-]+/[^[:space:]<>"'\''`]*|:[0-9]+)?([/?#][^[:space:]<>"'\''`]*)?[(@]?'

# Bare hosts (no scheme) only count when the TLD is on one of these lists,
# drawn from W3Techs' top ~100 TLDs by usage (Oct 2026) plus dev favourites.
# Strong: a bare name.tld is enough.
BARE_TLDS_STRONG="com org net edu gov mil biz io co me us uk de fr it nl be ch
at es se no dk fi ie cz sk hu ro gr hr si lt lv ee ua ru kz uz tr il ae sa ir
pk ng ke za ma eg jp kr cn tw hk sg my th vn ph au nz ca mx br cl pe uy eu xyz
gg ly fm tv local"
# Weak: TLDs that are also file extensions (README.md, main.rs, x.sh) or
# English words / code properties (user.id, rect.top, item.link,
# user.email, google.cloud). These need a lowercase host and a /path:
# claude.ai/code matches; README.md, Docker.app/Contents and df.info don't.
BARE_TLDS_WEAK="app ai id dev info int is to by bg gl email cloud top click page
link store site space live world online shop club vip tech blog fun life news
studio design art wiki land md py rs pl sh so tf cc in am ac mk pm mo ps ml pt
ar zip mov pro cat sc"
# Hosting platforms and dev sites whose bare hostnames are links on their own,
# even though their TLD is weak: myproj.vercel.app, fly.dev, dev.to.
BARE_KNOWN_HOSTS="vercel.app netlify.app web.app pages.dev workers.dev fly.dev
deno.dev ngrok.app ngrok-free.app replit.app streamlit.app surge.sh go.dev
web.dev bun.sh deno.land dev.to"

# Post-process candidates (one per line), GFM-autolink style:
#  - strip trailing punctuation: . , ; : ! ? * _ ~ ' |
#  - strip a trailing ) ] } only when it's unbalanced, so
#    wiki/Foo_(bar) survives but (see https://x.com) loses its paren
#  - normalize git remotes (git@host:a/b.git, ssh://git@host/a/b.git,
#    host:a/b.git) → https://host/a/b; bare hosts get https:// (http://
#    for localhost and *.local dev servers)
#  - scheme URLs need a plausible host: localhost, IPv4, [IPv6], or
#    dotted / single-label / IDN names (http://nas:5000 is fine)
#  - bare hosts need www.x.y, localhost:port, a strong TLD, or a weak TLD
#    with a lowercase host plus a /path (or a known platform host), and
#    must not look like code: foo.at( calls, a.me@ emails,
#    import.meta.env.DEV / System.Net casing, com.example.app reverse-DNS
clean_urls() {
    LC_ALL=C awk -v strong="${BARE_TLDS_STRONG//$'\n'/ }" \
        -v weak="${BARE_TLDS_WEAK//$'\n'/ }" \
        -v known="${BARE_KNOWN_HOSTS//$'\n'/ }" '
    function count(s, ch,   n, i) {
        n = 0
        for (i = 1; i <= length(s); i++) if (substr(s, i, 1) == ch) n++
        return n
    }
    function ends(s, suf) {
        return length(s) >= length(suf) && substr(s, length(s) - length(suf) + 1) == suf
    }
    function is_known(h,   i) {
        for (i = 1; i <= nknown; i++)
            if (h == kh[i] || ends(h, "." kh[i])) return 1
        return 0
    }
    BEGIN {
        punct = ".,;:!?*_~|'\''"
        open[")"] = "("; open["]"] = "["; open["}"] = "{"
        n = split(strong, t); for (i = 1; i <= n; i++) tld_strong[t[i]] = 1
        n = split(weak, t);   for (i = 1; i <= n; i++) tld_weak[t[i]] = 1
        nknown = split(known, kh)
    }
    {
        u = $0
        sub(/^[^a-zA-Z0-9]/, "", u)   # leading delimiter from the bare-host branch
        # bare host glued to "(" or "@" is a method call or an email
        if (u !~ /^[a-zA-Z+]+:\/\// && u ~ /^[^\/?#]*[(@]$/) next
        do {
            changed = 0
            c = substr(u, length(u), 1)
            if (index(punct, c)) {
                u = substr(u, 1, length(u) - 1); changed = 1
            } else if (c in open && count(u, c) > count(u, open[c])) {
                u = substr(u, 1, length(u) - 1); changed = 1
            }
        } while (changed && length(u) > 0)

        if (u ~ /^((git\+)?ssh:\/\/)?git@/) {
            # git@host:a/b.git, ssh://git@host[:port]/a/b.git → https://host/a/b
            sub(/^((git\+)?ssh:\/\/)?git@/, "", u)
            if (u ~ /^[^\/]*:[0-9]+\//) sub(/:[0-9]+\//, "/", u)
            else if (u ~ /^[^\/]*:/) sub(/:/, "/", u)
            sub(/\.git$/, "", u)
            u = "https://" u
        } else if (u !~ /^[a-zA-Z]+:\/\//) {
            # bare host: decide by TLD before giving it a scheme
            raw = u; sub(/[:\/?#].*$/, "", raw)   # host as written
            rest = substr(u, length(raw) + 1)
            host = tolower(raw)
            nlabels = split(host, lbl, ".")
            tld = lbl[nlabels]
            rtld = substr(raw, length(raw) - length(tld) + 1)

            # scp-style "host:owner/repo.git" (git push output) — but not :port
            if (rest ~ /^:[^\/]*\// && rest !~ /^:[0-9]+\//) {
                rest = "/" substr(rest, 2); sub(/\.git$/, "", rest)
            }

            if (host == "localhost") {
                if (rest !~ /^:[0-9]+/) next
            } else {
                # code, not hosts: import.meta.env.DEV, System.Net, com.example.app
                if (rtld ~ /[A-Z]/ && raw ~ /[a-z]/) next
                if (nlabels >= 3 && lbl[1] ~ /^(com|org|net|io)$/) next
                if (host ~ /^www\./) {
                    if (nlabels < 3) next
                } else if (!(tld in tld_strong)) {
                    if (!(tld in tld_weak)) next
                    if (!is_known(host) && (raw ~ /[A-Z]/ || rest !~ /^(:[0-9]+)?\/./)) next
                }
            }
            u = ((host == "localhost" || tld == "local") ? "http://" : "https://") raw rest
        }

        # host = between "://" (and any user:pw@) and the next / ? #, minus :port
        host = u
        sub(/^[a-zA-Z]+:\/\//, "", host)
        sub(/[\/?#].*$/, "", host)
        sub(/^.*@/, "", host)
        if (host ~ /^\[/) sub(/\]:[0-9]*$/, "]", host)
        else sub(/:[0-9]*$/, "", host)
        host = tolower(host)

        # labels: ASCII alnum/hyphen or raw UTF-8 bytes (IDN like müller.de);
        # single-label hosts are fine with an explicit scheme (http://nas:5000)
        if (host ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ ||
            host ~ /^\[[0-9a-f:.]+\]$/ ||
            host ~ /^(([a-z0-9]|[\200-\377])([a-z0-9-]|[\200-\377])*\.)*([a-z0-9]|[\200-\377])([a-z0-9-]|[\200-\377])*$/)
            print u
    }'
}

# stdin (pane text) → one cleaned URL per line, in order of appearance
find_urls() {
    split_punct | grep -oiE "$URL_PATTERN" | clean_urls
}

# Turn Unicode punctuation and TUI borders into spaces before matching, so
# they end a URL (https://ejfox.com—great, ejfox.com’s, “ejfox.com”,
# 見て https://x.com/。) and also count as a delimiter before a bare host.
# Also split comma-glued URLs: https://a.com,https://b.com. Byte-wise
# (LC_ALL=C) so it behaves the same in any locale.
split_punct() {
    # shellcheck disable=SC1112  # the smart quotes are the point
    LC_ALL=C awk '{
        gsub(/—|–|‘|’|“|”|«|»|…|。|，|、|：|；|！|？|（|）|「|」|【|】|│|┃|║|┆|┊|▏|▕/, " ")
        gsub(/,https:\/\//, " https://"); gsub(/,http:\/\//, " http://")
        print
    }'
}

# Portable reverse-lines: tac (GNU) → tail -r (macOS) → awk fallback
reverse_lines() {
    if command -v tac &>/dev/null; then
        tac
    elif tail -r /dev/null 2>/dev/null; then
        tail -r
    else
        awk '{lines[NR]=$0} END {for(i=NR;i>=1;i--) print lines[i]}'
    fi
}

get_pane_label() {
    tmux display-message -t "$1" -p '#{pane_current_command}' 2>/dev/null | head -c 12
}

extract_urls() {
    local pane="$1" label="$2"
    local content
    content=$(tmux capture-pane -pJ -t "$pane" -S-"$SCROLLBACK" 2>/dev/null)
    if [ -n "$label" ] && [ "$SHOW_LABELS" = "true" ]; then
        echo "$content" | find_urls | while read -r url; do echo "[$label] $url"; done
    else
        echo "$content" | find_urls
    fi
}

save_history() {
    [ -z "$HISTORY_FILE" ] && return
    echo "$(date +%s) $1" >> "$HISTORY_FILE"
    if [ -f "$HISTORY_FILE" ] && [ "$(wc -l < "$HISTORY_FILE")" -gt "$HISTORY_MAX" ]; then
        tail -n "$HISTORY_MAX" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
}

show_history() {
    [ -z "$HISTORY_FILE" ] || [ ! -f "$HISTORY_FILE" ] && return
    reverse_lines < "$HISTORY_FILE" | awk '!seen[$2]++ {print $2}'
}

copy_url() {
    local url="$1"
    # Check for user's copy-command first
    local copy_cmd
    copy_cmd=$(tmux show-option -gqv "copy-command")
    if [ -n "$copy_cmd" ]; then
        echo -n "$url" | eval "$copy_cmd"
    elif command -v pbcopy &>/dev/null; then
        echo -n "$url" | pbcopy
    elif command -v xclip &>/dev/null; then
        echo -n "$url" | xclip -selection clipboard
    elif command -v wl-copy &>/dev/null; then
        echo -n "$url" | wl-copy
    else
        # Fallback: tmux buffer
        tmux set-buffer "$url"
        tmux display-message "Copied to tmux buffer (prefix+] to paste)"
        return
    fi
    tmux display-message "Copied: ${url:0:50}..."
}

open_url() {
    local url="$1"
    if command -v open &>/dev/null; then
        open "$url"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url"
    else
        tmux display-message "No browser found"
        return 1
    fi
    # Extract domain for display
    local domain
    domain=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|' | head -c 40)
    tmux display-message "Opened: $domain"
}

# ============================================================================
# Gather URLs based on scope
# ============================================================================

# CURRENT_PANE is read by gather_urls in session/window scopes.
# Tests may override it before calling; defaults to empty when sourced
# outside a tmux context.
: "${CURRENT_PANE:=}"

gather_urls() {
    case "$SCOPE" in
        history)
            show_history
            ;;
        session)
            {
                extract_urls "$CURRENT_PANE" "" | awk '!seen[$0]++' | reverse_lines
                for pane in $(tmux list-panes -a -F '#{pane_id}'); do
                    [ "$pane" != "$CURRENT_PANE" ] && extract_urls "$pane" "$(get_pane_label "$pane")" | awk '!seen[$0]++' | reverse_lines
                done
            } | grep -v '^$' | awk '!seen[$0]++'
            ;;
        window)
            {
                extract_urls "$CURRENT_PANE" "" | awk '!seen[$0]++' | reverse_lines
                for pane in $(tmux list-panes -F '#{pane_id}'); do
                    [ "$pane" != "$CURRENT_PANE" ] && extract_urls "$pane" "$(get_pane_label "$pane")" | awk '!seen[$0]++' | reverse_lines
                done
            } | grep -v '^$' | awk '!seen[$0]++'
            ;;
        *)
            tmux capture-pane -pJ -S-"$SCROLLBACK" 2>/dev/null | find_urls | awk '!seen[$0]++' | reverse_lines
            ;;
    esac
}

# ============================================================================
# Main
# ============================================================================

# Only run main flow when executed directly; when sourced (e.g. from tests),
# the functions and constants above are available without side effects.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    CURRENT_PANE=$(tmux display-message -p '#{pane_id}')

    URLS=$(gather_urls)

    if [ -z "$URLS" ]; then
        tmux display-message "No URLs found"
        exit 0
    fi

    # Colors use terminal ANSI palette (-1 = default, 0-15 = ANSI indexes)
    # so the popup follows whatever theme the terminal is currently using —
    # no system-appearance detection or config sourcing required.
    SELECTED=$(echo "$URLS" | fzf --no-info --no-sort --reverse \
        --bind 'j:down,k:up,space:accept,enter:accept' \
        --color='fg:-1,bg:-1,hl:1,fg+:-1,bg+:8,hl+:1,gutter:-1' \
        --color='pointer:1,marker:1,prompt:1,spinner:1,info:8,header:8,border:8' \
        --header '↵/space: select · type to filter')

    [ -z "$SELECTED" ] && exit 0

    # Strip label if present (e.g. "[nvim] https://…" → "https://…")
    URL="${SELECTED#\[*\] }"

    # Save to history
    [ -n "$HISTORY_FILE" ] && save_history "$URL"

    # Execute action
    case "$ACTION" in
        copy) copy_url "$URL" ;;
        buffer) tmux set-buffer "$URL" && tmux display-message "Saved to tmux buffer" ;;
        *) open_url "$URL" ;;
    esac
fi
