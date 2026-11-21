#!/usr/bin/env bash

POMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POMO_STATE="$POMO_ROOT/.pomo-state.json"
# shellcheck disable=SC1091
. "$POMO_ROOT/.env"
if [[ -z ${TIMER_ACCESS_PATH:-} ]]; then
    "$POMO_ROOT/scripts/cloud/prepare_env.sh" || return 1 2>/dev/null || exit 1
    . "$POMO_ROOT/.env"
fi

if [[ -z ${TIMER_FQDN:-} || ! ${TIMER_ACCESS_PATH:-} =~ ^[0-9a-f]{24}$ ]]; then
    echo 'Set TIMER_FQDN and TIMER_ACCESS_PATH in .env' >&2
    return 1 2>/dev/null || exit 1
fi

pomo_request() {
    local method=$1 route=$2 body=${3:-}
    local url="https://${TIMER_FQDN}/${TIMER_ACCESS_PATH}/api/${route}"
    if [[ -n $body ]]; then
        curl --fail --silent --show-error --max-time 5 -X "$method" \
            -H 'Content-Type: application/json' -H 'Cache-Control: no-store' \
            --data "$body" "$url"
    else
        curl --fail --silent --show-error --max-time 5 -X "$method" \
            -H 'Cache-Control: no-store' "$url"
    fi
}

pomo_record_sync_attempt() {
    printf '%s\n' "$(date +%s)" > "$POMO_ROOT/.pomo-last-attempt"
}

pomo_store_response() {
    local response=$1 temp title start flag color
    umask 077
    temp=$(mktemp "$POMO_ROOT/.pomo-state.XXXXXX") || return 1
    if ! printf '%s' "$response" | jq -ec --argjson fetchedAt "$(date +%s)" \
        'select(has("durationSeconds") and has("startedAtMillis") and has("stoppedElapsedMillis")) + {fetchedAtSeconds: $fetchedAt}' > "$temp"; then
        rm -f "$temp"
        return 1
    fi
    mv "$temp" "$POMO_STATE"
    title=$(jq -r '.sessionName // ""' "$POMO_STATE")
    start=$(jq -r '(.startedAtMillis // 0) / 1000 | floor' "$POMO_STATE")
    flag=0
    (( start > 0 )) && flag=1
    tmux set-environment -g POMODORO_SESSION_TITLE "$title" >/dev/null 2>&1 || true
    tmux set-environment -g POMODORO_START_UNIXTIME "$start" >/dev/null 2>&1 || true
    tmux set-environment -g POMODORO_SESSION_FLAG "$flag" >/dev/null 2>&1 || true
    if [[ $(tmux show-option -gv @pomo_name 2>/dev/null) != "$title" ]]; then
        tmux set-option -gq @pomo_name "$title" >/dev/null 2>&1 || true
    fi
    if (( flag )); then
        color=brightred
    else
        color=green
    fi
    if [[ $(tmux show-option -gv @pomo_color 2>/dev/null) != "$color" ]]; then
        tmux set-option -gq @pomo_color "$color" >/dev/null 2>&1 || true
    fi
    tmux refresh-client -S >/dev/null 2>&1 || true
}
