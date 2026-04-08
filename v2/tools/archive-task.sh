#!/usr/bin/env bash
set -euo pipefail

# Archive task state during closeout: copy plan.md + review.md to .harness/archive/{date}-{slug}/
# Usage: bash v2/tools/archive-task.sh [--repo-root <path>] [--dry-run] [--keep-originals]

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
PLAN="${HARNESS_DIR}/plan.md"
REVIEW="${HARNESS_DIR}/review.md"
ARCHIVE_BASE="${HARNESS_DIR}/archive"
SCRATCH_ACTIVE="${REPO_ROOT}/.context/baton/active"

# --- Validate plan.md exists ---
if [[ ! -f "$PLAN" ]]; then
  echo "Error: ${PLAN} not found. Nothing to archive." >&2
  exit 1
fi

# --- Extract slug from plan.md title ---
# Reads first line matching "# Plan: {name}"
title_line=$(grep -m1 '^# Plan:' "$PLAN" 2>/dev/null || true)
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

# --- Dry run: show what the closeout archive step would do, then exit ---
if $DRY_RUN; then
  echo "[dry-run] Would archive to: ${target_dir}"
echo "[dry-run] Files: plan.md$([ -f "$REVIEW" ] && echo ", review.md")"
  review_count=0
  for review_round in "${HARNESS_DIR}"/review-round-*.md; do
    [[ -f "$review_round" ]] && review_count=$((review_count + 1))
  done
  [[ $review_count -gt 0 ]] && echo "[dry-run] + ${review_count} review-round-*.md files"
  [[ -d "$SCRATCH_ACTIVE" ]] && echo "[dry-run] + scratch state from .context/baton/active/"
  exit 0
fi

mkdir -p "$target_dir"

# --- Copy files ---
cp "$PLAN" "${target_dir}/plan.md"

# review.md is optional
if [[ -f "$REVIEW" ]]; then
  cp "$REVIEW" "${target_dir}/review.md"
fi

# Copy all per-round review files (review-round-*.md)
review_count=0
for review_round in "${HARNESS_DIR}"/review-round-*.md; do
  [[ -f "$review_round" ]] || continue
  cp "$review_round" "${target_dir}/"
  review_count=$((review_count + 1))
done

# Copy scratch state when present. It is non-canonical, but useful local history.
scratch_copied=false
if [[ -d "$SCRATCH_ACTIVE" ]]; then
  mkdir -p "${target_dir}/scratch"
  cp -R "$SCRATCH_ACTIVE"/. "${target_dir}/scratch/"
  scratch_copied=true
fi

# --- Integrity check ---
if ! diff -q "$PLAN" "${target_dir}/plan.md" >/dev/null 2>&1; then
  echo "Error: plan.md copy verification failed." >&2
  exit 1
fi
if [[ -f "$REVIEW" ]] && ! diff -q "$REVIEW" "${target_dir}/review.md" >/dev/null 2>&1; then
  echo "Error: review.md copy verification failed." >&2
  exit 1
fi

# --- Remove originals (unless --keep-originals) ---
if ! $KEEP_ORIGINALS; then
  rm "$PLAN"
  [[ -f "$REVIEW" ]] && rm "$REVIEW"
  for review_round in "${HARNESS_DIR}"/review-round-*.md; do
    [[ -f "$review_round" ]] && rm "$review_round"
  done
  # Clean up transient checkpoint (not archived — content is in plan.md)
  [[ -f "${HARNESS_DIR}/exploration.md" ]] && rm "${HARNESS_DIR}/exploration.md"
  [[ -d "$SCRATCH_ACTIVE" ]] && rm -rf "$SCRATCH_ACTIVE"
fi

# --- Summary ---
echo "Closeout archive written to: ${target_dir}"
echo "  - plan.md ✅"
if [[ -f "${target_dir}/review.md" ]]; then
  echo "  - review.md ✅"
else
  echo "  - review.md (not present, skipped)"
fi
if [[ $review_count -gt 0 ]]; then
  echo "  - ${review_count} review-round-*.md files ✅"
fi
if $scratch_copied; then
  echo "  - scratch/ ✅"
fi
if $KEEP_ORIGINALS; then echo "  - originals kept (--keep-originals)"; fi
