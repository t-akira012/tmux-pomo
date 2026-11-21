#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/api.sh" || exit 1
if [[ -z ${1:-} ]]; then
    tmux display-message 'POMODORO: require session title.'
    exit 1
fi
body=$(jq -nc --arg name "$*" '{name: $name}')
if ! response=$(pomo_request PUT session-name "$body"); then
    tmux display-message 'Session name update failed'
    exit 1
fi
pomo_store_response "$response" || exit 1
if response=$(pomo_request POST start) && pomo_store_response "$response"; then
    tmux set -g status-interval 1
    tmux display-message 'POMODORO started!!'
else
    tmux display-message 'Timer start failed'
fi
