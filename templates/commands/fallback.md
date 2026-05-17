Switch the fallback proxy backend. Usage: /fallback <provider>

Available providers: claude, deepseek, gemini, chatgpt

If an argument is given, run this bash command to switch:
echo '{"mode": "$ARGUMENTS"}' > ~/.claude-code-proxy/sticky-config.json

Then confirm to the user which provider is now active.

If no argument is given, run:
cat ~/.claude-code-proxy/sticky-config.json

And report the current mode.
