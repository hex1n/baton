#!/usr/bin/env bash
# junction.sh — Shared utility for creating directory junctions/symlinks/copies.
# Source this file; do not execute directly.

# atomic_junction SRC DST
#   Creates a directory junction (Windows), symlink (Unix), or copy (fallback).
#   Returns 0 for junction/symlink, 1 for copy fallback.
atomic_junction() {
    local _src="$1" _dst="$2"

    # Remove existing target (old install, stale symlink, partial copy)
    if [ -e "$_dst" ] || [ -L "$_dst" ]; then
        rm -rf "$_dst"
    fi

    # 1. Try NTFS junction (Windows, no Developer Mode needed)
    if command -v cygpath >/dev/null 2>&1; then
        local _win_dst _win_src
        _win_dst="$(cygpath -w "$_dst")"
        _win_src="$(cygpath -w "$_src")"
        # Try with quoted paths first (handles spaces and special chars)
        cmd //c "mklink /J \"$_win_dst\" \"$_win_src\"" >/dev/null 2>&1 && return 0
        # Retry without inner quotes (some Git Bash versions need this)
        cmd //c "mklink /J $_win_dst $_win_src" >/dev/null 2>&1 && return 0
    fi

    # 2. Try symlink (Linux/macOS, or Windows with Developer Mode)
    ln -sf "$_src" "$_dst" 2>/dev/null && [ -L "$_dst" ] && return 0

    # 3. Fallback: copy
    cp -r "$_src" "$_dst"
    return 1
}
