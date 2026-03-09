#!/bin/sh
# install.sh — Global installer for baton plan-first workflow
# Usage: curl -fsSL https://raw.githubusercontent.com/hex1n/baton/master/install.sh | bash
#   or:  bash /path/to/baton/install.sh
set -eu

BATON_HOME="${BATON_HOME:-$HOME/.baton}"
BATON_REPO="${BATON_REPO:-https://github.com/hex1n/baton.git}"

echo "Installing baton..."

# 1. Ensure ~/.baton/ is a complete git repository
if [ -d "$BATON_HOME/.git" ]; then
    echo "  ✓ $BATON_HOME already exists"
    # Update to latest
    if git -C "$BATON_HOME" pull --ff-only 2>/dev/null; then
        echo "  ✓ Updated to latest"
    else
        echo "  ⚠ Could not auto-update (local changes?). Run: git -C $BATON_HOME pull --ff-only"
    fi
    # Convert full clone to sparse if not already
    if [ "$(git -C "$BATON_HOME" config core.sparseCheckout 2>/dev/null)" != "true" ]; then
        _git_ver="$(git --version | sed 's/[^0-9]*\([0-9]*\)\.\([0-9]*\).*/\1 \2/')"
        _git_major="${_git_ver%% *}"
        _git_minor="${_git_ver##* }"
        if [ "$_git_major" -gt 2 ] 2>/dev/null || { [ "$_git_major" -eq 2 ] && [ "$_git_minor" -ge 25 ]; } 2>/dev/null; then
            (cd "$BATON_HOME" && MSYS_NO_PATHCONV=1 git sparse-checkout set --no-cone /.baton /.claude/skills /bin /setup.sh /install.sh /.gitignore)
            echo "  ✓ Converted to sparse checkout"
        fi
    fi
elif [ -d "$BATON_HOME" ]; then
    echo "  ⚠ $BATON_HOME exists but is not a git repository"
    echo "  Remove it first: rm -rf $BATON_HOME"
    exit 1
else
    echo "  Cloning baton to $BATON_HOME..."
    _git_ver="$(git --version | sed 's/[^0-9]*\([0-9]*\)\.\([0-9]*\).*/\1 \2/')"
    _git_major="${_git_ver%% *}"
    _git_minor="${_git_ver##* }"
    if [ "$_git_major" -gt 2 ] 2>/dev/null || { [ "$_git_major" -eq 2 ] && [ "$_git_minor" -ge 25 ]; } 2>/dev/null; then
        git clone --depth 1 --filter=blob:none --sparse "$BATON_REPO" "$BATON_HOME"
        (cd "$BATON_HOME" && MSYS_NO_PATHCONV=1 git sparse-checkout set --no-cone /.baton /.claude/skills /bin /setup.sh /install.sh /.gitignore)
        echo "  ✓ Cloned baton (sparse: only essential files)"
    else
        git clone --depth 1 "$BATON_REPO" "$BATON_HOME"
        echo "  ✓ Cloned baton (shallow — upgrade git to 2.25+ for sparse checkout)"
    fi
fi

# 2. Create bin/baton executable
mkdir -p "$BATON_HOME/bin"
if [ -f "$BATON_HOME/bin/baton" ]; then
    echo "  ✓ bin/baton already exists"
else
    echo "  ✓ bin/baton ready"
fi
chmod +x "$BATON_HOME/bin/baton"

# 3. Add ~/.baton/bin to PATH
BATON_BIN="$BATON_HOME/bin"
PATH_ENTRY="export PATH=\"$BATON_BIN:\$PATH\""

add_to_profile() {
    _profile="$1"
    if [ -f "$_profile" ] && grep -qF "$BATON_BIN" "$_profile" 2>/dev/null; then
        echo "  ✓ PATH already in $_profile"
        return
    fi
    if [ -f "$_profile" ] || [ "$2" = "create" ]; then
        printf '\n# baton CLI\n%s\n' "$PATH_ENTRY" >> "$_profile"
        echo "  ✓ Added PATH to $_profile"
    fi
}

# Detect shell and add to appropriate profile
ADDED_PATH=0
for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [ -f "$profile" ]; then
        add_to_profile "$profile" "existing"
        ADDED_PATH=1
    fi
done

if [ "$ADDED_PATH" = "0" ]; then
    # No profile found, create .bashrc
    add_to_profile "$HOME/.bashrc" "create"
fi

# 4. Auto-init current directory
export PATH="$BATON_BIN:$PATH"

echo ""
echo "Done! Baton installed to $BATON_HOME"
echo ""

if bash "$BATON_HOME/setup.sh" "$(pwd)"; then
    echo ""
    echo "  ✓ Initialized baton in current directory"
else
    echo ""
    echo "  ⚠ Auto-init failed. To initialize manually:"
    echo "    cd /path/to/project && baton init"
fi

echo ""
echo "  Restart your shell or run:"
echo "    export PATH=\"$BATON_BIN:\$PATH\""
