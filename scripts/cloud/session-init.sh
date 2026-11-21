#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/api.sh" || exit 1
response=$(pomo_request POST start) && pomo_store_response "$response" || tmux display-message 'Timer start failed'
