#!/bin/bash

# Create default AI config if it doesn't exist
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/setup_ai_config.sh" ]; then
    bash "$SCRIPT_DIR/setup_ai_config.sh"
fi

cd .resources/main/
bash menu.sh
