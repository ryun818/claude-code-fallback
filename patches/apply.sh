#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_DIR="${1:-$HOME/.claude-code-proxy}"

if [ ! -d "$PROXY_DIR/.git" ]; then
  echo "Error: $PROXY_DIR is not a git repository"
  exit 1
fi

cd "$PROXY_DIR"
git apply "$SCRIPT_DIR/oauth-passthrough.patch"
echo "Patch applied successfully to $PROXY_DIR"
