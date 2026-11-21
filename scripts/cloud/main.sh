#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/api.sh" || exit 1
COMMAND=${1:-}

sync_state() {
    local response
    response=$(pomo_request GET timer) && pomo_store_response "$response"
}

maybe_sync() {
    local last=0 now
    if [[ -f $POMO_STATE ]]; then
        last=$(jq -r '.fetchedAtSeconds // 0' "$POMO_STATE" 2>/dev/null) || last=0
    fi
    now=$(date +%s)
    if (( now - last >= 15 )); then
        sync_state >/dev/null 2>&1 || true
    fi
}

show_time() {
    maybe_sync
    if [[ ! -f $POMO_STATE ]]; then
        printf '%s\n' '--:--'
        return
    fi
    local duration start stopped server fetched elapsed remaining seconds prefix=''
    read -r duration start stopped server fetched < <(
        jq -r '[.durationSeconds, (.startedAtMillis // -1), (.stoppedElapsedMillis // 0), .serverNowMillis, .fetchedAtSeconds] | @tsv' "$POMO_STATE"
    )
    if (( start >= 0 )); then
        elapsed=$(( (server - start) / 1000 + $(date +%s) - fetched ))
    else
        elapsed=$(( stopped / 1000 ))
    fi
    (( elapsed < 0 )) && elapsed=0
    remaining=$(( duration - elapsed ))
    if (( remaining < 0 )); then
        prefix='+'
        seconds=$(( -remaining ))
    else
        seconds=$remaining
    fi
    printf '%s%02d:%02d\n' "$prefix" "$((seconds / 60))" "$((seconds % 60))"
}

case "$COMMAND" in
    time) show_time ;;
    name) [[ -f $POMO_STATE ]] && jq -r '.sessionName // ""' "$POMO_STATE" ;;
    color)
        if [[ -f $POMO_STATE ]] && jq -e '.startedAtMillis != null' "$POMO_STATE" >/dev/null; then
            printf '%s\n' brightred
        else
            printf '%s\n' green
        fi
        ;;
    sync) sync_state || tmux display-message 'Timer sync failed' ;;
    start)
        if ! sync_state; then
            tmux display-message 'Timer sync failed'
        elif jq -e '.startedAtMillis != null' "$POMO_STATE" >/dev/null; then
            tmux display-message 'Session has already started.'
        else
            tmux command-prompt -p 'POMODORO start:' "run-shell '$CURRENT_DIR/session-init.sh \"%%\"'"
        fi
        ;;
    stop)
        local_response=$(pomo_request POST stop) && pomo_store_response "$local_response" || tmux display-message 'Timer stop failed'
        ;;
    overwrite)
        tmux command-prompt -p 'Session name:' "run-shell '$CURRENT_DIR/session-overwrite.sh \"%%\"'"
        ;;
esac
