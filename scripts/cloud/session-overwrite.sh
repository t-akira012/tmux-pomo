#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/api.sh" || exit 1
body=$(jq -nc --arg name "$*" '{name: $name}')
response=$(pomo_request PUT session-name "$body") && pomo_store_response "$response" || tmux display-message 'Session name update failed'
