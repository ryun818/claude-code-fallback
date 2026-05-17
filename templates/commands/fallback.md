Switch the fallback proxy backend. Usage: /fallback <provider>

Available providers: claude, deepseek, gemini, chatgpt

Write the following JSON to ~/.claude-code-proxy/sticky-config.json:
{"mode": "$ARGUMENTS"}

Then confirm to the user which provider is now active. If no argument is given, read the current sticky-config.json and report the current mode.
