#!/bin/bash
# setup_ai_config.sh — Create default AI provider config if it doesn't exist
# Config location: ~/.42examshell_ai.conf

AI_CONFIG_FILE="$HOME/.42examshell_ai.conf"

if [ -f "$AI_CONFIG_FILE" ]; then
    echo "AI config already exists at $AI_CONFIG_FILE — skipping."
    exit 0
fi

echo "Creating default AI config at $AI_CONFIG_FILE ..."

cat > "$AI_CONFIG_FILE" << 'EOF'
# 42 ExamShell — AI Provider Configuration
#
# Each provider section has: endpoint, key, models, default_model
# - key: your API key (set with: setai key <provider> <key>)
# - models: space-separated list of model names
# - default_model: the model used by 'analysis' command
#
# Switch active provider: setai use <provider>
# Add more models:       setai addmodel <provider> <model>
# Set default model:     setai defaultmodel <provider> <model>
# Show config:           showai

[openai]
endpoint=https://api.openai.com/v1
key=
models=gpt-4o-mini gpt-4o gpt-4-turbo
default_model=gpt-4o-mini

[deepseek]
endpoint=https://api.deepseek.com/v1
key=
models=deepseek-chat deepseek-reasoner
default_model=deepseek-chat

[gemini]
endpoint=https://generativelanguage.googleapis.com/v1beta/openai
key=
models=gemini-2.0-flash gemini-2.5-flash gemini-2.5-pro
default_model=gemini-2.0-flash

[openrouter]
endpoint=https://openrouter.ai/api/v1
key=
models=google/gemini-2.0-flash-001 deepseek/deepseek-chat-v3-0324 openai/gpt-4o-mini meta-llama/llama-4-maverick
default_model=google/gemini-2.0-flash-001

[active]
provider=gemini
EOF

chmod 600 "$AI_CONFIG_FILE"
echo "✔ Default AI config created."
echo "  Active provider: gemini"
echo "  Set your API key with: setai key <provider> <key>"
echo "  Switch provider with: setai use <provider>"
