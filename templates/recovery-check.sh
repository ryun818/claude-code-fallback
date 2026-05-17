#!/bin/bash

STICKY="$HOME/.claude-code-proxy/sticky-config.json"
NOTIFIER="/opt/homebrew/bin/terminal-notifier"
CLAUDE="$(which claude 2>/dev/null || echo "$HOME/.local/bin/claude")"

# Claude mode ならチェック不要
MODE=$(jq -r '.mode // "claude"' "$STICKY" 2>/dev/null)
[ "$MODE" = "claude" ] && exit 0

# Pro Max アカウント経由で疎通テスト
RESPONSE=$("$CLAUDE" -p "." --model haiku 2>&1)
EXIT_CODE=$?

echo "$(date): Health check exit_code=${EXIT_CODE}"

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "$(date): API not yet recovered (exit ${EXIT_CODE})"
  exit 0
fi

# 復旧通知
RESULT=$("$NOTIFIER" \
  -title "Claude API recovered" \
  -subtitle "Currently using fallback ($MODE)" \
  -message "Switch back to Claude?" \
  -actions "Switch back,Wait 1 hour" \
  -closeLabel "Wait 1 hour" \
  -timeout 600 \
  -sound Glass \
  -group "claude-proxy-recovery")

echo "$(date): User selected: ${RESULT}"

if [ "$RESULT" = "Switch back" ]; then
  echo '{"mode": "claude"}' > "$STICKY"

  "$NOTIFIER" \
    -title "Claude restored" \
    -message "Back to normal mode" \
    -sound Tink \
    -group "claude-proxy-recovery"

  echo "$(date): Switched back to Claude"
fi

exit 0
