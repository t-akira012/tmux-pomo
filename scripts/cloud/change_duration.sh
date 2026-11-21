#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/api.sh" || exit 1
minutes=${1:-}
if [[ ! $minutes =~ ^[0-9]+$ ]] || (( 10#$minutes < 1 || 10#$minutes > 1440 )); then
    echo 'Usage: change_duration.sh <minutes: 1-1440>' >&2
    exit 2
fi
seconds=$(( 10#$minutes * 60 ))
body=$(jq -nc --argjson seconds "$seconds" '{seconds: $seconds}')
response=$(pomo_request PUT duration "$body") && pomo_store_response "$response" || {
    echo 'Timer duration update failed' >&2
    exit 1
}
