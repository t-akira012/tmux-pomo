#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/api.sh" || exit 1
COMMAND=${1:-}

sync_state() {
    pomo_sync_state
}

maybe_sync() {
    local last=0 now interval=${SYNC_INTERVAL:-30}
    if [[ ! $interval =~ ^[1-9][0-9]*$ ]]; then
        return 1
    fi
    if [[ -f $POMO_ROOT/.pomo-last-attempt ]]; then
        read -r last < "$POMO_ROOT/.pomo-last-attempt" || last=0
    fi
    [[ $last =~ ^[0-9]+$ ]] || last=0
    now=$(date +%s)
    if (( now - last >= interval )); then
        lockf -t 0 "$POMO_ROOT/.pomo-sync.lock" "$CURRENT_DIR/main.sh" sync_if_due >/dev/null 2>&1 || true
    fi
}

show_time() {
    maybe_sync
    if [[ ! -f $POMO_STATE ]]; then
        printf '%s\n' '--:--'
        return
    fi
    local duration start stopped server fetched elapsed remaining finished
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
    if (( start < 0 )); then
        pomo_set_color green
        finished=$(jq -r '.finishedAtMillis // empty' "$POMO_STATE")
        if [[ -n $finished ]]; then
            pomo_format_time "$(( finished / 1000 ))"
        else
            printf '%s\n' '--:--'
        fi
    elif (( remaining <= 0 )); then
        pomo_set_color green
        tmux set-environment -g POMODORO_SESSION_FLAG 0 >/dev/null 2>&1 || true
        pomo_format_time "$(( start / 1000 + duration ))"
    else
        pomo_set_color brightred
        printf '%02d:%02d\n' "$((remaining / 60))" "$((remaining % 60))"
    fi
}

case "$COMMAND" in
    time) show_time ;;
    sync_if_due)
        interval=${SYNC_INTERVAL:-30}
        [[ $interval =~ ^[1-9][0-9]*$ ]] || exit 1
        last=0
        if [[ -f $POMO_ROOT/.pomo-last-attempt ]]; then
            read -r last < "$POMO_ROOT/.pomo-last-attempt" || last=0
        fi
        [[ $last =~ ^[0-9]+$ ]] || last=0
        if (( $(date +%s) - last >= interval )); then
            sync_state >/dev/null 2>&1
        fi
        ;;
    name) [[ -f $POMO_STATE ]] && jq -r '.sessionName // ""' "$POMO_STATE" ;;
    color)
        if [[ -f $POMO_STATE ]] && jq -e --argjson now "$(date +%s)" \
            '.startedAtMillis != null and
             (.serverNowMillis + ($now - .fetchedAtSeconds) * 1000 < .startedAtMillis + .durationSeconds * 1000)' "$POMO_STATE" >/dev/null; then
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
        tmux command-prompt -p 'Do you want stop a Pomodoro Session?(press Enter or CTRL-C):' \
            "run-shell '$CURRENT_DIR/main.sh stop_ok'"
        ;;
    stop_ok)
        if ! sync_state; then
            tmux display-message 'Timer sync failed'
        elif ! jq -e '.startedAtMillis != null' "$POMO_STATE" >/dev/null; then
            tmux display-message 'Session has not started.'
        else
            local_response=$(pomo_request POST stop) && pomo_store_response "$local_response" && {
                tmux set-environment -g POMODORO_FINISHED_TIME "$(date +%H:%M)"
                tmux display-message 'POMODORO stopped!!!'
            } || tmux display-message 'Timer stop failed'
        fi
        ;;
    overwrite)
        if ! sync_state; then
            tmux display-message 'Timer sync failed'
        elif ! jq -e '.startedAtMillis != null' "$POMO_STATE" >/dev/null; then
            tmux display-message 'Session has not started.'
        else
            tmux command-prompt -p 'POMODORO:' "run-shell '$CURRENT_DIR/session-overwrite.sh \"%%\"'"
        fi
        ;;
esac
