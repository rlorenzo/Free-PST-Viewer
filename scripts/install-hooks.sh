#!/bin/bash
# Installs Git hooks for the Free PST Viewer project

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_DIR/.git/hooks"

echo "Installing Git hooks..."

if [ ! -d "$HOOKS_DIR" ]; then
    echo "Error: .git/hooks directory not found. Are you in a Git repository?"
    exit 1
fi

cp "$SCRIPT_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "Pre-commit hook installed successfully."
echo "The hook will run SwiftLint on staged Swift files before each commit."
