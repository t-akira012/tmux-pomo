#!/usr/bin/env bash
POMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POMO_STATE="$POMO_ROOT/.pomo-state.json"
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
        curl --fail --silent --show-error --max-time 5 -X "$method" -H 'Content-Type: application/json' -H 'Cache-Control: no-store' --data "$body" "$url"
    else
        curl --fail --silent --show-error --max-time 5 -X "$method" -H 'Cache-Control: no-store' "$url"
    fi
}
pomo_record_sync_attempt() { date +%s > "$POMO_ROOT/.pomo-last-attempt"; }
pomo_load_state() {
    [[ -f $POMO_STATE ]] || return 1
    read -r pomo_duration pomo_start pomo_completed pomo_server pomo_fetched < <(
        jq -r '[.durationSeconds, (.startedAtMillis // -1), (.completedAtMillis // -1), .serverNowMillis, .fetchedAtSeconds] | @tsv' "$POMO_STATE"
    )
    pomo_now=$(( pomo_server + ($(date +%s) - pomo_fetched) * 1000 ))
    pomo_end=$pomo_completed
    pomo_running=0
    if (( pomo_start >= 0 && pomo_completed < 0 )); then
        pomo_end=$(( pomo_start + pomo_duration * 1000 ))
        (( pomo_now < pomo_end )) && pomo_running=1
    fi
    return 0
}
pomo_render_time() {
    pomo_load_state || { printf '%s\n' '--:--'; return; }
    if (( pomo_running )); then
        local seconds=$(( (pomo_end - pomo_now + 999) / 1000 ))
        printf '%02d:%02d\n' "$((seconds / 60))" "$((seconds % 60))"
    elif (( pomo_end >= 0 )); then
        date -r "$((pomo_end / 1000))" +%H:%M
    else
        printf '%s\n' '--:--'
    fi
}
pomo_publish_state() {
    pomo_load_state || return 0
    local title color start=0
    title=$(jq -r '.sessionName // ""' "$POMO_STATE")
    if (( pomo_running )); then color=brightred; start=$((pomo_start / 1000)); else color=green; fi
    tmux set-environment -g POMODORO_SESSION_TITLE "$title" >/dev/null 2>&1 || true
    tmux set-environment -g POMODORO_START_UNIXTIME "$start" >/dev/null 2>&1 || true
    tmux set-environment -g POMODORO_SESSION_FLAG "$pomo_running" >/dev/null 2>&1 || true
    if (( !pomo_running && pomo_end >= 0 )); then
        tmux set-environment -g POMODORO_FINISHED_TIME "$(pomo_render_time)" >/dev/null 2>&1 || true
    fi
    if [[ $(tmux show-option -gv @pomo_name 2>/dev/null) != "$title" ]]; then tmux set-option -gq @pomo_name "$title" >/dev/null 2>&1 || true; fi
    if [[ $(tmux show-option -gv @pomo_color 2>/dev/null) != "$color" ]]; then tmux set-option -gq @pomo_color "$color" >/dev/null 2>&1 || true; fi
}
pomo_store_response() {
    local response=$1 temp
    umask 077
    temp=$(mktemp "$POMO_ROOT/.pomo-state.XXXXXX") || return 1
    if ! printf '%s' "$response" | jq -ec --argjson fetchedAt "$(date +%s)" 'select(has("id") and has("durationSeconds") and has("startedAtMillis") and has("completedAtMillis") and has("serverNowMillis")) + {fetchedAtSeconds:$fetchedAt}' > "$temp"; then
        rm -f "$temp"; return 1
    fi
    mv "$temp" "$POMO_STATE"
    pomo_publish_state
    tmux refresh-client -S >/dev/null 2>&1 || true
}
