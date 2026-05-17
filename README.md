# claude-code-fallback

Claude Code のフォールバックプロキシ。Claude API の障害・制限時に **セッションを維持したまま** DeepSeek / Gemini / ChatGPT に切り替えます。

**Pro Max / Pro / Teams / API キー** — どの認証方式でも動作します。

## Features

- **OAuth パススルー** - Pro Max / Pro / Teams の認証をそのまま転送。追加コスト $0
- **セッション維持** - 切替時にセッションが切れない。会話履歴・メモリ・タスクすべて引き継ぎ
- **`/fallback` コマンド** - セッション内から `/fallback deepseek` で即切替
- **複数プロバイダ** - DeepSeek, Gemini, ChatGPT に対応。config で追加可能
- **macOS 通知** - 429/5xx 検知時にボタン付き通知。ワンクリックで切替
- **自動復旧チェック** - 1時間ごとに Claude の復旧を確認、通知で戻す
- **launchd 常駐** - PC再起動後も自動起動

## Architecture

```
Claude Code (any auth: Pro Max / Pro / Teams / API key)
  → localhost:3456 (proxy)
    ├─ mode=claude   : api.anthropic.com (headers passthrough)
    ├─ mode=deepseek : api.deepseek.com (format conversion)
    ├─ mode=gemini   : Gemini API (format conversion)
    └─ mode=chatgpt  : api.openai.com (format conversion)
```

Based on [UniClaudeProxy](https://github.com/vibheksoni/UniClaudeProxy) with OAuth passthrough patch.

## Quick Start (macOS)

```bash
git clone https://github.com/ryun818/claude-code-fallback.git
cd claude-code-fallback
./setup.sh
```

Then edit `~/.claude-code-proxy/config.json` with your API keys and run `source ~/.zshrc`.

## Usage

**Normal**: Just use `claude` as usual. No extra cost.

**Slash command (in session)**:
```
/fallback deepseek   # Switch to DeepSeek
/fallback gemini     # Switch to Gemini
/fallback chatgpt    # Switch to ChatGPT
/fallback claude     # Switch back to Claude
```

**When Claude is limited/down**:
- macOS notification appears with provider buttons
- Click to switch — your session continues seamlessly

**When Claude recovers**:
- Automatic health check every hour
- macOS notification: "Claude recovered"
- Click "Switch back" to return to Claude

## Adding Providers

Edit `~/.claude-code-proxy/config.json`:

1. Add the provider to `providers`
2. Add a mapping to `fallback_models`

```json
{
  "fallback_models": {
    "deepseek": "deepseek/deepseek-chat",
    "my-provider": "myprovider/model-name"
  },
  "providers": {
    "myprovider": {
      "provider_type": "openai",
      "api_key": "YOUR_KEY",
      "base_url": "https://api.example.com/v1",
      "models": {
        "model-name": { "name": "Model Name" }
      }
    }
  }
}
```

Config changes are hot-reloaded (no restart needed).

## Troubleshooting

| Issue | Fix |
|---|---|
| Proxy not starting | `cat /tmp/claude-proxy.err` |
| No notifications | System Settings > Notifications > terminal-notifier > Allow |
| Auth error (401) | Check that `ANTHROPIC_BASE_URL=http://127.0.0.1:3456` is set |
| Patch conflicts | `cd ~/.claude-code-proxy && git stash && git pull && git stash pop` |

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.$(whoami).claude-proxy.plist
launchctl unload ~/Library/LaunchAgents/com.$(whoami).claude-proxy-recovery.plist
rm -rf ~/.claude-code-proxy
rm ~/Library/LaunchAgents/com.$(whoami).claude-proxy*.plist
rm ~/.claude/commands/fallback.md
# Remove ANTHROPIC_BASE_URL from ~/.zshrc
```

## License

MIT
