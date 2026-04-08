#!/usr/bin/env bash
set -euo pipefail

# Archive completed round: copy brief.md + eval.md to .harness/archive/{date}-{slug}/
# Usage: bash v2/tools/archive-round.sh [--repo-root <path>] [--dry-run] [--keep-originals]

# --- Parse args ---
REPO_ROOT="."
DRY_RUN=false
KEEP_ORIGINALS=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --keep-originals) KEEP_ORIGINALS=true; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

HARNESS_DIR="${REPO_ROOT}/.harness"
BRIEF="${HARNESS_DIR}/brief.md"
EVAL="${HARNESS_DIR}/eval.md"
ARCHIVE_BASE="${HARNESS_DIR}/archive"

# --- Validate brief.md exists ---
if [[ ! -f "$BRIEF" ]]; then
  echo "Error: ${BRIEF} not found. Nothing to archive." >&2
  exit 1
fi

# --- Extract slug from brief.md title ---
# Reads first line matching "# Brief: {name}"
title_line=$(grep -m1 '^# Brief:' "$BRIEF" 2>/dev/null || true)
if [[ -z "$title_line" ]]; then
  slug="unnamed-task"
else
  raw_name="${title_line#*: }"
  # Lowercase, spaces→hyphens, strip non-alphanumeric (except hyphens)
  ascii_slug=$(echo "$raw_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
  if [[ -z "$ascii_slug" ]]; then
    # Non-ASCII title (e.g., Chinese) — use short hash for a stable, unique slug
    slug="task-$(echo "$raw_name" | md5sum | cut -c1-8)"
  else
    slug="$ascii_slug"
  fi
fi

# --- Build target directory ---
today=$(date +%Y-%m-%d)
target_dir="${ARCHIVE_BASE}/${today}-${slug}"

# Handle duplicate: append -N suffix
if [[ -d "$target_dir" ]]; then
  counter=2
  while [[ -d "${target_dir}-${counter}" ]]; do
    counter=$((counter + 1))
  done
  target_dir="${target_dir}-${counter}"
fi

# --- Dry run: show what would happen, then exit ---
if $DRY_RUN; then
  echo "[dry-run] Would archive to: ${target_dir}"
  echo "[dry-run] Files: brief.md$([ -f "$EVAL" ] && echo ", eval.md")"
  eval_count=0
  for eval_round in "${HARNESS_DIR}"/eval-round-*.md; do
    [[ -f "$eval_round" ]] && eval_count=$((eval_count + 1))
  done
  [[ $eval_count -gt 0 ]] && echo "[dry-run] + ${eval_count} eval-round-*.md files"
  exit 0
fi

mkdir -p "$target_dir"

# --- Copy files ---
cp "$BRIEF" "${target_dir}/brief.md"

# eval.md is optional
if [[ -f "$EVAL" ]]; then
  cp "$EVAL" "${target_dir}/eval.md"
fi

# Copy all per-round eval files (eval-round-*.md)
eval_count=0
for eval_round in "${HARNESS_DIR}"/eval-round-*.md; do
  [[ -f "$eval_round" ]] || continue
  cp "$eval_round" "${target_dir}/"
  eval_count=$((eval_count + 1))
done

# --- Integrity check ---
if ! diff -q "$BRIEF" "${target_dir}/brief.md" >/dev/null 2>&1; then
  echo "Error: brief.md copy verification failed." >&2
  exit 1
fi
if [[ -f "$EVAL" ]] && ! diff -q "$EVAL" "${target_dir}/eval.md" >/dev/null 2>&1; then
  echo "Error: eval.md copy verification failed." >&2
  exit 1
fi

# --- Remove originals (unless --keep-originals) ---
if ! $KEEP_ORIGINALS; then
  rm "$BRIEF"
  [[ -f "$EVAL" ]] && rm "$EVAL"
  for eval_round in "${HARNESS_DIR}"/eval-round-*.md; do
    [[ -f "$eval_round" ]] && rm "$eval_round"
  done
fi

# --- Summary ---
echo "Archived to: ${target_dir}"
echo "  - brief.md ✅"
if [[ -f "${target_dir}/eval.md" ]]; then
  echo "  - eval.md ✅"
else
  echo "  - eval.md (not present, skipped)"
fi
if [[ $eval_count -gt 0 ]]; then
  echo "  - ${eval_count} eval-round-*.md files ✅"
fi
if $KEEP_ORIGINALS; then echo "  - originals kept (--keep-originals)"; fi
