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
    got=$(printf '%s\n' "$input" | grep -oE "$URL_PATTERN" | head -n1)
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
    got=$(printf '%s\n' "$input" | grep -oE "$URL_PATTERN" | wc -l | tr -d ' ')
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
    got=$(printf '%s\n' "$input" | grep -oE "$URL_PATTERN" || true)
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
assert_no_match '192.168.1.1 bare ip'      # no bare-IP support in current regex
assert_no_match 'file:///etc/passwd'       # no file:// support
assert_no_match 'mailto:a@b.com'           # no mailto support

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
