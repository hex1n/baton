#!/bin/sh
# install.sh — Global installer for baton plan-first workflow (v5)
# Usage: curl -fsSL https://raw.githubusercontent.com/hex1n/baton/master/install.sh | bash
#   or:  bash /path/to/baton/install.sh
set -eu

BATON_HOME="${BATON_HOME:-$HOME/.baton}"
BATON_REPO="${BATON_REPO:-https://github.com/hex1n/baton.git}"

echo "Installing baton v5..."

# 1. Ensure ~/.baton/ is a git repository
if [ -d "$BATON_HOME/.git" ]; then
    echo "  ✓ $BATON_HOME already exists"
    if git -C "$BATON_HOME" pull --ff-only 2>/dev/null; then
        echo "  ✓ Updated to latest"
    else
        echo "  ⚠ Could not auto-update (local changes?). Run: git -C $BATON_HOME pull --ff-only"
    fi
elif [ -d "$BATON_HOME" ]; then
    echo "  ⚠ $BATON_HOME exists but is not a git repository"
    echo "  Remove it first: rm -rf $BATON_HOME"
    exit 1
else
    echo "  Cloning baton to $BATON_HOME..."
    git clone --depth 1 "$BATON_REPO" "$BATON_HOME"
    echo "  ✓ Cloned baton"
fi

# 2. Add ~/.baton/bin to PATH
BATON_BIN="$BATON_HOME/bin"
chmod +x "$BATON_BIN/baton" 2>/dev/null || true

PATH_ENTRY="export PATH=\"$BATON_BIN:\$PATH\""
for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [ -f "$profile" ] && ! grep -qF "$BATON_BIN" "$profile" 2>/dev/null; then
        printf '\n# baton CLI\n%s\n' "$PATH_ENTRY" >> "$profile"
        echo "  ✓ Added PATH to $profile"
    fi
done

# 3. Run user-level setup (skills, hooks, constitution)
export PATH="$BATON_BIN:$PATH"
bash "$BATON_HOME/setup.sh"

echo ""
echo "  Restart your shell or run:"
echo "    export PATH=\"$BATON_BIN:\$PATH\""
