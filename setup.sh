#!/bin/bash
set -euo pipefail

PROXY_DIR="$HOME/.claude-code-proxy"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USERNAME="$(whoami)"
SHELL_RC="$HOME/.zshrc"

echo "=== claude-code-fallback setup ==="
echo ""

# 1. Check dependencies
echo "[1/8] Checking dependencies..."
MISSING=""
command -v python3 >/dev/null 2>&1 || MISSING="$MISSING python3"
command -v jq >/dev/null 2>&1 || MISSING="$MISSING jq"

if [ -n "$MISSING" ]; then
  echo "Missing:$MISSING"
  if command -v brew >/dev/null 2>&1; then
    echo "Installing via Homebrew..."
    brew install $MISSING
  else
    echo "Error: Please install:$MISSING"
    exit 1
  fi
fi

# terminal-notifier (macOS only)
if [ "$(uname)" = "Darwin" ]; then
  if ! command -v terminal-notifier >/dev/null 2>&1; then
    echo "Installing terminal-notifier..."
    brew install terminal-notifier
  fi
fi

echo "  All dependencies OK"

# 2. Clone UniClaudeProxy
echo "[2/8] Setting up UniClaudeProxy..."
if [ -d "$PROXY_DIR" ]; then
  echo "  $PROXY_DIR already exists. Pulling latest..."
  cd "$PROXY_DIR" && git pull --ff-only 2>/dev/null || true
else
  git clone https://github.com/vibheksoni/UniClaudeProxy.git "$PROXY_DIR"
fi

# 3. Apply patch
echo "[3/8] Applying OAuth passthrough patch..."
cd "$PROXY_DIR"
if git apply --check "$SCRIPT_DIR/patches/oauth-passthrough.patch" 2>/dev/null; then
  git apply "$SCRIPT_DIR/patches/oauth-passthrough.patch"
  echo "  Patch applied"
else
  echo "  Patch already applied or conflicts detected, skipping"
fi

# 4. Python venv
echo "[4/8] Setting up Python environment..."
if [ ! -d "$PROXY_DIR/.venv" ]; then
  python3 -m venv "$PROXY_DIR/.venv"
fi
"$PROXY_DIR/.venv/bin/pip" install -q -r "$PROXY_DIR/requirements.txt"
echo "  Python environment ready"

# 5. Config files
echo "[5/8] Setting up configuration..."
if [ ! -f "$PROXY_DIR/config.json" ]; then
  cp "$SCRIPT_DIR/templates/config.example.json" "$PROXY_DIR/config.json"
  echo "  Created config.json from template"
  echo "  >>> IMPORTANT: Edit $PROXY_DIR/config.json and add your API keys <<<"
else
  echo "  config.json already exists, skipping"
fi

cp "$SCRIPT_DIR/templates/sticky-config.json" "$PROXY_DIR/sticky-config.json" 2>/dev/null || true
cp "$SCRIPT_DIR/templates/recovery-check.sh" "$PROXY_DIR/recovery-check.sh" 2>/dev/null || true
chmod +x "$PROXY_DIR/recovery-check.sh"

# 6. launchd plist (macOS only)
if [ "$(uname)" = "Darwin" ]; then
  echo "[6/8] Installing launchd services..."
  LAUNCH_DIR="$HOME/Library/LaunchAgents"
  mkdir -p "$LAUNCH_DIR"

  for plist in com.user.claude-proxy.plist com.user.claude-proxy-recovery.plist; do
    TARGET="$LAUNCH_DIR/$(echo "$plist" | sed "s/user/$USERNAME/g")"
    sed -e "s|__HOME__|$HOME|g" -e "s|__USERNAME__|$USERNAME|g" \
      "$SCRIPT_DIR/launchd/$plist" > "$TARGET"
    plutil -lint "$TARGET" >/dev/null
  done
  echo "  launchd plists installed"

  # 7. Load services
  echo "[7/8] Starting services..."
  PROXY_PLIST="$LAUNCH_DIR/com.$USERNAME.claude-proxy.plist"
  RECOVERY_PLIST="$LAUNCH_DIR/com.$USERNAME.claude-proxy-recovery.plist"

  launchctl unload "$PROXY_PLIST" 2>/dev/null || true
  launchctl unload "$RECOVERY_PLIST" 2>/dev/null || true
  launchctl load -w "$PROXY_PLIST"
  launchctl load -w "$RECOVERY_PLIST"

  sleep 3
  if curl -s http://127.0.0.1:3456/health | grep -q '"ok"'; then
    echo "  Proxy is running on http://127.0.0.1:3456"
  else
    echo "  Warning: Proxy may not have started. Check /tmp/claude-proxy.err"
  fi
else
  echo "[6/8] Skipping launchd (not macOS)"
  echo "[7/8] Skipping service start"
  echo "  To start manually: cd $PROXY_DIR && .venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 3456"
fi

# 8. Slash command
echo "[8/9] Installing /fallback slash command..."
COMMANDS_DIR="$HOME/.claude/commands"
mkdir -p "$COMMANDS_DIR"
if [ ! -f "$COMMANDS_DIR/fallback.md" ]; then
  cp "$SCRIPT_DIR/templates/commands/fallback.md" "$COMMANDS_DIR/fallback.md"
  echo "  /fallback command installed"
else
  echo "  /fallback command already exists, skipping"
fi

# 9. Shell config
echo "[9/9] Configuring shell..."
if [ -f "$SHELL_RC" ]; then
  if ! grep -q 'ANTHROPIC_BASE_URL.*127.0.0.1:3456' "$SHELL_RC"; then
    echo '' >> "$SHELL_RC"
    echo '# Claude Code fallback proxy' >> "$SHELL_RC"
    echo 'export ANTHROPIC_BASE_URL=http://127.0.0.1:3456' >> "$SHELL_RC"
    echo "  Added ANTHROPIC_BASE_URL to $SHELL_RC"
  else
    echo "  ANTHROPIC_BASE_URL already configured"
  fi
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit $PROXY_DIR/config.json and add your API keys"
echo "  2. Run: source $SHELL_RC"
echo "  3. Start Claude Code as usual: claude"
echo ""
echo "Switching modes:"
echo '  echo '"'"'{"mode": "deepseek"}'"'"' > ~/.claude-code-proxy/sticky-config.json  # Switch to DeepSeek'
echo '  echo '"'"'{"mode": "claude"}'"'"'   > ~/.claude-code-proxy/sticky-config.json  # Switch back to Claude'
echo ""
echo "Logs:"
echo "  tail -f /tmp/claude-proxy.log"
echo "  tail -f /tmp/claude-proxy.err"
