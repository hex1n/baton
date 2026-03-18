#!/bin/bash
# test-junction.sh — Tests for atomic_junction utility
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_eq() {
    TOTAL=$((TOTAL + 1))
    if [ "$1" = "$2" ]; then echo "  pass: $3"; PASS=$((PASS + 1))
    else echo "  FAIL: $3 (expected '$2', got '$1')"; FAIL=$((FAIL + 1)); fi
}

assert_true() {
    TOTAL=$((TOTAL + 1))
    if eval "$1"; then echo "  pass: $2"; PASS=$((PASS + 1))
    else echo "  FAIL: $2"; FAIL=$((FAIL + 1)); fi
}

. "$SCRIPT_DIR/../.baton/hooks/lib/junction.sh"

# --- Test: creates junction/symlink/copy to a directory ---
echo "=== atomic_junction creates link ==="
mkdir -p "$tmp/source" && echo "content" > "$tmp/source/file.txt"
atomic_junction "$tmp/source" "$tmp/target" || true
_content="$(cat "$tmp/target/file.txt")"
assert_eq "$_content" "content" "target/file.txt readable through junction"

# --- Test: target is a directory ---
echo "=== target is directory ==="
assert_true '[ -d "$tmp/target" ]' "target is a directory"

# --- Test: new files in source visible through junction ---
echo "=== new file visibility ==="
echo "new" > "$tmp/source/new.txt"
if [ -f "$tmp/target/new.txt" ]; then
    _vis="yes"
else
    _vis="no"
fi
echo "  info: new file visibility = $_vis (junction/symlink=yes, copy=no)"

# --- Test: replaces existing target ---
echo "=== replaces existing target ==="
mkdir -p "$tmp/old-target" && echo "old" > "$tmp/old-target/stale.txt"
mkdir -p "$tmp/source2" && echo "fresh" > "$tmp/source2/fresh.txt"
atomic_junction "$tmp/source2" "$tmp/old-target" || true
assert_eq "$(cat "$tmp/old-target/fresh.txt")" "fresh" "old target replaced with new source"
assert_true '[ ! -f "$tmp/old-target/stale.txt" ]' "old stale file gone"

# --- Test: replaces existing symlink ---
echo "=== replaces existing symlink ==="
mkdir -p "$tmp/src-a" && echo "a" > "$tmp/src-a/a.txt"
mkdir -p "$tmp/src-b" && echo "b" > "$tmp/src-b/b.txt"
atomic_junction "$tmp/src-a" "$tmp/link-target" || true
assert_eq "$(cat "$tmp/link-target/a.txt")" "a" "first junction works"
atomic_junction "$tmp/src-b" "$tmp/link-target" || true
assert_eq "$(cat "$tmp/link-target/b.txt")" "b" "re-junction to different source works"

# --- Test: return code ---
echo "=== return code ==="
_rc=0
atomic_junction "$tmp/source" "$tmp/target3" || _rc=$?
echo "  info: atomic_junction returned $_rc (0=junction/symlink, 1=copy)"

echo ""
echo "junction tests: $PASS passed, $FAIL failed out of $TOTAL"
[ "$FAIL" -eq 0 ]
