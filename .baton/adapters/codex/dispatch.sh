#!/usr/bin/env bash
# dispatch-codex.sh — Codex adapter for dispatch.sh
# Codex uses stdout as context for the agent. Always exit 0.
set -eu

_dir="$(cd "$(dirname "$0")" && pwd)"
bash "$_dir/../../hooks/dispatch.sh" "$@" 2>&1 || true
exit 0
