#!/bin/bash
# ============================================================================
# tmux-link-grab test suite
#
# Sources grab-links.sh to exercise its URL regex and helper functions
# without invoking the interactive fzf/tmux flow. Run from the repo root
# (or anywhere) with: ./tests/run.sh
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/grab-links.sh"

PASS=0
FAIL=0
FAILED_CASES=()

record_pass() { PASS=$((PASS + 1)); }
record_fail() {
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$1")
}

# assert_match <input> <expected-first-url>
assert_match() {
    local input="$1" expected="$2"
    local got
    got=$(printf '%s\n' "$input" | find_urls | head -n1)
    if [ "$got" = "$expected" ]; then
        record_pass
    else
        record_fail "match: '$input' expected='$expected' got='$got'"
    fi
}

# assert_count <input> <expected-count>
assert_count() {
    local input="$1" expected="$2"
    local got
    got=$(printf '%s\n' "$input" | find_urls | wc -l | tr -d ' ')
    if [ "$got" = "$expected" ]; then
        record_pass
    else
        record_fail "count: '$input' expected=$expected got=$got"
    fi
}

# assert_no_match <input>
assert_no_match() {
    local input="$1"
    local got
    got=$(printf '%s\n' "$input" | find_urls || true)
    if [ -z "$got" ]; then
        record_pass
    else
        record_fail "no-match: '$input' should not match but got='$got'"
    fi
}

# assert_eq <label> <expected> <got>
assert_eq() {
    local label="$1" expected="$2" got="$3"
    if [ "$got" = "$expected" ]; then
        record_pass
    else
        record_fail "$label: expected='$expected' got='$got'"
    fi
}

# ============================================================================
# URL regex tests
# ============================================================================

echo "URL regex tests..."

# --- happy path ---
assert_match 'visit https://example.com today'        'https://example.com'
assert_match 'see https://example.com/path/to/page'   'https://example.com/path/to/page'
assert_match 'query https://example.com?q=foo&r=bar'  'https://example.com?q=foo&r=bar'
assert_match 'http only http://example.com works'     'http://example.com'
assert_match 'deep https://sub.domain.example.co.uk'  'https://sub.domain.example.co.uk'
assert_match 'with fragment https://example.com#top'  'https://example.com#top'
assert_match 'encoded https://example.com/%20path'    'https://example.com/%20path'

# --- localhost special case ---
assert_match 'run http://localhost:3000/api here'     'http://localhost:3000/api'
assert_match 'bare http://localhost test'             'http://localhost'

# --- terminator chars (should NOT be captured) ---
assert_match '(see https://example.com)'              'https://example.com'
assert_match '<a href="https://example.com">x</a>'    'https://example.com'
# shellcheck disable=SC2016  # backticks here are literal test input, not command substitution
assert_match 'quoted `https://example.com` backtick'  'https://example.com'
assert_match 'angle https://example.com>rest'         'https://example.com'

# --- multiple URLs ---
assert_count 'visit https://a.com and https://b.org'   2
assert_count 'three https://a.com https://b.com https://c.com'  3
assert_count 'no urls here'                            0

# --- should NOT match ---
assert_no_match 'plain text no urls'
assert_no_match 'ftp://files.example.com'  # regex is https? only
assert_no_match '192.168.1.1 bare ip'      # IPs need a scheme
assert_no_match 'file:///etc/passwd'       # no file:// support
assert_no_match 'mailto:a@b.com'           # no mailto support
assert_no_match 'https:// dangling scheme'
assert_match 'http://foo single label'  'http://foo'  # explicit scheme: intranet hosts ok
assert_no_match 'see config.json and v1.2.3'

# --- trailing punctuation (GFM autolink rules) ---
assert_match 'Done, see https://example.com.'          'https://example.com'
assert_match 'a https://a.com, b'                      'https://a.com'
assert_match 'semi https://a.com; ok'                  'https://a.com'
assert_match 'wow https://example.com/x!'              'https://example.com/x'
assert_match 'huh https://example.com/x?'              'https://example.com/x'
assert_match 'md **https://example.com/bold** bold'    'https://example.com/bold'
assert_match 'dev http://localhost:3000.'              'http://localhost:3000'
assert_count 'urls: https://a.com, https://b.com; ok'  2

# --- balanced brackets ---
assert_match 'https://en.wikipedia.org/wiki/Foo_(bar) x'      'https://en.wikipedia.org/wiki/Foo_(bar)'
assert_match '(see https://en.wikipedia.org/wiki/Foo_(bar))'  'https://en.wikipedia.org/wiki/Foo_(bar)'
assert_match '[link](https://example.com/x) md'              'https://example.com/x'
assert_match '[https://example.com/bracket]'                  'https://example.com/bracket'
assert_match '{https://example.com/brace}'                    'https://example.com/brace'

# --- TUI decorations / smart quotes ---
assert_match '│https://example.com/tui│'             'https://example.com/tui'
assert_match '“https://example.com/smart”'           'https://example.com/smart'

# --- Unicode punctuation glued to a URL (smart punctuation, CJK) ---
assert_match 'https://ejfox.com—it rules'             'https://ejfox.com'
assert_match 'https://ejfox.com–dash'                 'https://ejfox.com'
# shellcheck disable=SC1112  # curly apostrophe is the test input
assert_match 'https://ejfox.com’s blog'               'https://ejfox.com'
assert_match 'https://ejfox.com…'                     'https://ejfox.com'
assert_match 'https://ejfox.com”.'                    'https://ejfox.com'
assert_match 'https://ejfox.com/»'                    'https://ejfox.com/'
assert_match 'https://ejfox.com/。'                   'https://ejfox.com/'
assert_match 'https://ejfox.com/，next'               'https://ejfox.com/'
assert_match 'check out ejfox.com—it rules'           'https://ejfox.com'
# shellcheck disable=SC1112  # curly apostrophe is the test input
assert_match 'check out ejfox.com’s blog'             'https://ejfox.com'
assert_match '“ejfox.com”.'                           'https://ejfox.com'
assert_match '（ejfox.com/a）'                        'https://ejfox.com/a'
assert_match 'https://ja.wikipedia.org/wiki/東京'     'https://ja.wikipedia.org/wiki/東京'

# --- plain punctuation after a bare host ---
assert_match 'check out ejfox.com, it rules'          'https://ejfox.com'
assert_match 'check out ejfox.com. Then'              'https://ejfox.com'
assert_match 'check out ejfox.com! wow'               'https://ejfox.com'
assert_match 'check out ejfox.com? maybe'             'https://ejfox.com'
assert_match 'check out ejfox.com: nice'              'https://ejfox.com'
assert_match "check out ejfox.com's blog"             'https://ejfox.com'
assert_match '(ejfox.com).'                           'https://ejfox.com'
assert_match 'ejfox.com!!!'                           'https://ejfox.com'
assert_match 'ejfox.com...'                           'https://ejfox.com'
assert_match 'https://ejfox.com/a!).'                 'https://ejfox.com/a'

# --- comma-glued URLs split ---
assert_count 'https://ejfox.com/a,https://b.com'      2
assert_count 'ejfox.com,https://b.com'                2

# --- hosts ---
assert_match 'http://192.168.1.10:8080/admin ip'      'http://192.168.1.10:8080/admin'
assert_match 'vite http://127.0.0.1:5173/'            'http://127.0.0.1:5173/'
assert_match 'py http://0.0.0.0:8000'                 'http://0.0.0.0:8000'
assert_match 'v6 http://[::1]:3000/'                  'http://[::1]:3000/'
assert_match 'HTTPS://EXAMPLE.COM/upper'              'HTTPS://EXAMPLE.COM/upper'
assert_match 'port https://example.com:8443/p'        'https://example.com:8443/p'
assert_match 'auth https://user:pw@example.com/a'     'https://user:pw@example.com/a'

# --- normalized forms ---
assert_match 'bare www.example.com/no-scheme'         'https://www.example.com/no-scheme'
assert_match 'git@github.com:ejfox/tmux-link-grab.git' 'https://github.com/ejfox/tmux-link-grab'
assert_count 'https://www.example.com once'           1

# --- bare hosts: strong TLDs ---
assert_match 'clone github.com/ejfox/tmux-link-grab'  'https://github.com/ejfox/tmux-link-grab'
assert_match 'see example.com for details.'           'https://example.com'
assert_match '(docs at docs.python.org/3/library)'    'https://docs.python.org/3/library'
assert_match 'url=news.ycombinator.com/item?id=1'     'https://news.ycombinator.com/item?id=1'
assert_match 'deploy to fly.dev'                      'https://fly.dev'
assert_match 'www.example.xyz/a'                      'https://www.example.xyz/a'
assert_count '- foo.com, bar.org; baz.net.'           3
assert_count 'https://github.com/a/b and gitlab.com/c/d' 2

# --- bare hosts: weak TLDs need a path or subdomain ---
assert_match 'claude.ai/code'                         'https://claude.ai/code'
assert_match 'myproj.vercel.app'                      'https://myproj.vercel.app'
assert_match 'bun.sh/docs'                            'https://bun.sh/docs'
assert_match 'amazon.in/deals'                        'https://amazon.in/deals'
assert_no_match 'claude.ai'
assert_no_match 'open README.md and main.rs:42:5'
assert_no_match 'python setup.py install'
assert_no_match 'requirements.in model.pt archive.zip'
assert_no_match 'user.id = row.id'
assert_no_match 'Safari.app'

# --- bare hosts: dev servers ---
assert_match 'ready on localhost:3000/dashboard'      'http://localhost:3000/dashboard'
assert_match 'raspberrypi.local:8080'                 'http://raspberrypi.local:8080'
assert_no_match 'just localhost here'

# --- bare hosts: things that are not links ---
assert_no_match 'email me at ej@ejfox.com'
assert_no_match 'ls /Applications/Safari.app ~/.local/bin'
assert_no_match 'console.log(foo.bar) express.static'
assert_no_match 'const last = arr.at(-1)'
assert_no_match 'if (Object.is(a, b)) x'

# --- IDN / unicode / punycode hosts ---
assert_match 'visit https://müller.de/pfad now'       'https://müller.de/pfad'
assert_match 'punycode https://xn--n3h.com/test'       'https://xn--n3h.com/test'

# --- rejected scheme hosts ---
assert_no_match 'https:// x'
# shellcheck disable=SC2016
assert_no_match 'template https://${domain}/api'

# --- single-label hosts (valid now) ---
assert_match 'ssh to http://nas:5000/ now'             'http://nas:5000/'
assert_match 'home http://homeassistant:8123 dashboard' 'http://homeassistant:8123'

# --- trailing cleanup: extra GFM chars ---
assert_match '|https://x.com|'                         'https://x.com'
assert_match 'star https://example.com/x*'             'https://example.com/x'
assert_match 'under https://example.com/x_'            'https://example.com/x'
assert_match 'tilde https://example.com/x~'            'https://example.com/x'
assert_match "apos https://example.com/x'"             'https://example.com/x'
assert_match 'pipe https://example.com/x|'             'https://example.com/x'
assert_match 'colon https://example.com/x:'            'https://example.com/x'

# --- unbalanced bracket stripping ---
assert_match '[markdown](https://example.com/path)'    'https://example.com/path'
assert_match 'see https://example.com/x] now'          'https://example.com/x'
assert_match 'see https://example.com/x} now'          'https://example.com/x'

# --- nested URLs kept whole ---
assert_match 'archive https://web.archive.org/web/2020/https://x.com/a done' 'https://web.archive.org/web/2020/https://x.com/a'

# --- git remote normalization ---
assert_match 'git@github.com:a/b.git'                  'https://github.com/a/b'
assert_match 'ssh://git@github.com/a/b.git'            'https://github.com/a/b'
assert_match 'git+ssh://git@github.com/a/b.git'        'https://github.com/a/b'
assert_match 'ssh://git@host.com:2222/a/b.git'         'https://host.com/a/b'
assert_match 'To github.com:ejfox/tmux-link-grab.git'  'https://github.com/ejfox/tmux-link-grab'
assert_match 'git+https://github.com/a/b.git'          'https://github.com/a/b.git'
assert_match 'origin  git@github.com:ejfox/tmux-link-grab.git (fetch)' 'https://github.com/ejfox/tmux-link-grab'
assert_match 'remote: github.com/ejfox/tmux-link-grab.git (fetch)'     'https://github.com/ejfox/tmux-link-grab.git'

# --- npm / pnpm / vite / next dev server banners ---
assert_match '  ➜  Local:   http://localhost:5173/'    'http://localhost:5173/'
assert_match '  ➜  Network: http://192.168.1.5:5173/'  'http://192.168.1.5:5173/'
assert_match 'Local:            http://localhost:3000' 'http://localhost:3000'
assert_no_match 'info  - Loaded env from .env.local'
assert_match 'npm ERR! A complete log of this run can be found: see https://docs.npmjs.com/errors for help' 'https://docs.npmjs.com/errors'
assert_no_match 'npm ERR! code ERESOLVE'

# --- python tracebacks / uvicorn / flask banners ---
assert_match 'INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)' 'http://127.0.0.1:8000'
assert_match ' * Running on http://127.0.0.1:5000/ (Press CTRL+C to quit)' 'http://127.0.0.1:5000/'
assert_no_match '  File "app.py", line 42, in <module>'
assert_no_match 'from google.cloud import storage'

# --- go.mod lines ---
assert_match 'github.com/spf13/cobra v1.8.0'           'https://github.com/spf13/cobra'
assert_match 'require github.com/stretchr/testify v1.9.0 // indirect' 'https://github.com/stretchr/testify'
assert_no_match 'see go.mod and go.sum'

# --- docker image refs ---
assert_match 'docker pull ghcr.io/ejfox/app:latest'    'https://ghcr.io/ejfox/app:latest'
assert_no_match 'FROM node:20-alpine AS build'

# --- curl | bash installers ---
assert_match 'curl -fsSL https://get.docker.com | sh'  'https://get.docker.com'
assert_match 'curl -sSf https://sh.rustup.rs | sh'     'https://sh.rustup.rs'

# --- log lines with url= ---
assert_match 'level=info msg=request url=https://api.example.com/v1/users status=200' 'https://api.example.com/v1/users'
assert_match 'GET /health url=example.com/health 200 OK' 'https://example.com/health'

# --- markdown links / images / autolinks / reference links ---
assert_match '[docs](https://example.com/docs)'        'https://example.com/docs'
assert_match '![alt text](https://example.com/img.png)' 'https://example.com/img.png'
assert_match '<https://example.com/autolink>'          'https://example.com/autolink'
assert_match '[ref]: https://example.com/reference "Title"' 'https://example.com/reference'

# --- HTML href/src ---
assert_match '<a href="https://example.com/page">link</a>' 'https://example.com/page'
assert_match '<img src="https://example.com/image.jpg" alt="x">' 'https://example.com/image.jpg'
assert_match '<link rel="stylesheet" href="https://cdn.example.com/style.css">' 'https://cdn.example.com/style.css'

# --- JSON / YAML values ---
assert_match '"homepage": "https://example.com/pkg",' 'https://example.com/pkg'
assert_match 'url: https://example.com/yaml'           'https://example.com/yaml'
assert_match '  repository: https://github.com/ejfox/thing' 'https://github.com/ejfox/thing'

# --- table pipes ---
assert_match '| Link | https://example.com/table |'    'https://example.com/table'
assert_count '| a | https://a.com | b | https://b.com |' 2

# --- nvim code lines: property access must NOT match ---
assert_no_match 'e.target.id'
assert_no_match 'req.params.id'
assert_no_match 'git config user.email'
assert_no_match 'bg = colors.bg'
assert_no_match 'item.link'
assert_no_match 'print(df.info)'
assert_no_match 'import.meta.env.DEV'
assert_no_match 'the type lives in System.Net namespace'
assert_no_match 'placeholder like Example.COM in docs'
assert_no_match 'Docker.app/Contents/MacOS'
assert_no_match 'com.example.app package'
assert_no_match 'com.apple.Safari bundle'
assert_no_match 'io.github.foo.dev package'
assert_no_match 'first.me@gmail.com'

# --- more false-positive-free cases (filenames, versions, paths) ---
assert_no_match 'CONTRIBUTING.md#setup'
assert_no_match 'README.md'
assert_no_match 'main.rs:42:5'
assert_no_match 'setup.py'
assert_no_match 'requirements.in'
assert_no_match 'e.g. i.e. v1.2.3 3.14 2.5GB'
assert_no_match 'package.json'
assert_no_match 'python3.11 --version'
assert_no_match 'file.tar.gz'
# shellcheck disable=SC2088  # literal tilde is the test input
assert_no_match '~/.local/bin'
assert_no_match 'contact support@example.com for help'

# --- ssh / dig / ping hostnames ---
assert_no_match 'ssh user@nas.local'
assert_match 'dig homeserver.local'                    'http://homeserver.local'
assert_match 'ping -c 4 router.local'                  'http://router.local'

# --- IPv6 ---
assert_match 'curl http://[2001:db8::1]:8080/path'     'http://[2001:db8::1]:8080/path'
assert_match 'connect to https://[::ffff:192.168.1.1]/' 'https://[::ffff:192.168.1.1]/'

# --- query strings, fragments, @user and ~user paths, percent-encoding ---
assert_match 'search https://example.com/search?q=foo&sort=desc&page=2' 'https://example.com/search?q=foo&sort=desc&page=2'
assert_match 'route https://example.com/app#/dashboard/settings' 'https://example.com/app#/dashboard/settings'
assert_match 'profile https://github.com/@ejfox'       'https://github.com/@ejfox'
assert_match 'check out github.com/@ejfox/repo'        'https://github.com/@ejfox/repo'
assert_match 'home https://example.com/~ejfox/home'    'https://example.com/~ejfox/home'
assert_match 'enc https://example.com/search?q=hello%20world%21' 'https://example.com/search?q=hello%20world%21'
assert_match 'reading https://example.com/article…'    'https://example.com/article'

# --- multiple URLs per line ---
assert_count 'mix http://localhost:3000 and https://example.com and github.com/a/b' 3
assert_count 'deps github.com/a/b gitlab.com/c/d bitbucket.org/e/f' 3

# --- bare hosts: weak TLD platform exceptions (no path needed) ---
assert_match 'deployed at myapp.netlify.app'           'https://myapp.netlify.app'
assert_match 'preview foo.pages.dev done'              'https://foo.pages.dev'
assert_match 'worker at myworker.workers.dev'          'https://myworker.workers.dev'
assert_match 'project.replit.app'                      'https://project.replit.app'
assert_match 'docs at go.dev/doc'                      'https://go.dev/doc'

# --- bare hosts: weak TLD needs path, and case rules ---
assert_no_match 'myapp.id'
assert_no_match 'service.cloud'
assert_match 'service.cloud/api/v1'                    'https://service.cloud/api/v1'
assert_match 'myapp.id/login'                          'https://myapp.id/login'
assert_no_match 'MyApp.id/login'

# --- bare hosts: www label count ---
assert_no_match 'www.x'
assert_match 'see www.example.com/path now'            'https://www.example.com/path'

# --- bare hosts: ports and case ---
assert_match 'db at example.com:8080/x'                'https://example.com:8080/x'
assert_match 'api.example.com:9000'                    'https://api.example.com:9000'
assert_match 'repo GITHUB.COM'                          'https://GITHUB.COM'

# --- bare hosts: leading delimiters ---
assert_match '(example.com/a)'                          'https://example.com/a'
assert_match '[example.com/b]'                          'https://example.com/b'
assert_match '"example.com/e"'                          'https://example.com/e'
# shellcheck disable=SC2016
assert_match '`example.com/g`'                          'https://example.com/g'
assert_match '*example.com/h*'                          'https://example.com/h'
assert_match ',example.com/k'                           'https://example.com/k'
assert_match 'xexample.com/test'                        'https://xexample.com/test'

# --- bare hosts: never mid-path, never mid-word ---
assert_no_match '/Applications/Foo.app/Contents'
assert_no_match 'cd /usr/local/bin'
assert_no_match '.example.com/l'          # "." isn't a delimiter (~/.local)
assert_no_match 'abc_example.com/test'

# ============================================================================
# Helper function tests
# ============================================================================

echo "Helper function tests..."

# --- reverse_lines ---
reversed=$(printf 'one\ntwo\nthree\n' | reverse_lines)
expected=$(printf 'three\ntwo\none')
assert_eq "reverse_lines: 3 lines" "$expected" "$reversed"

reversed_single=$(printf 'only\n' | reverse_lines)
assert_eq "reverse_lines: single line" "only" "$reversed_single"

reversed_empty=$(printf '' | reverse_lines)
assert_eq "reverse_lines: empty input" "" "$reversed_empty"

# --- label-strip parameter expansion (matches the main-block logic) ---
strip_label() { local s="$1"; echo "${s#\[*\] }"; }

assert_eq "strip_label: labeled"    "https://example.com"           "$(strip_label '[nvim] https://example.com')"
assert_eq "strip_label: unlabeled"  "https://example.com"           "$(strip_label 'https://example.com')"
assert_eq "strip_label: long label" "https://example.com/x"         "$(strip_label '[a-long-label] https://example.com/x')"
# No space after ] → not stripped (label convention requires "] ")
assert_eq "strip_label: no space"   "[nvim]https://example.com"     "$(strip_label '[nvim]https://example.com')"

# ============================================================================
# Summary
# ============================================================================

echo
echo "========================================="
echo "  $PASS passed, $FAIL failed"
echo "========================================="
if [ "$FAIL" -gt 0 ]; then
    echo
    echo "Failed cases:"
    for c in "${FAILED_CASES[@]}"; do
        echo "  - $c"
    done
    exit 1
fi
exit 0
