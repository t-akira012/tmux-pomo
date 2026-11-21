#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/api.sh" || exit 1
COMMAND=${1:-}

sync_state() { pomo_sync_state; }

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
    pomo_publish_state
    pomo_render_time
}

is_running() { pomo_load_state && (( pomo_running )); }

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
        if is_running; then printf '%s\n' brightred; else printf '%s\n' green; fi
        ;;
    sync) sync_state || tmux display-message 'Timer sync failed' ;;
    start)
        if ! sync_state; then
            tmux display-message 'Timer sync failed'
        elif is_running; then
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
        elif ! is_running; then
            tmux display-message 'Session has not started.'
        else
            local_response=$(pomo_request POST stop) && pomo_store_response "$local_response" && {
                tmux set-environment -g POMODORO_FINISHED_TIME "$(pomo_render_time)"
                tmux display-message 'POMODORO stopped!!!'
            } || tmux display-message 'Timer stop failed'
        fi
        ;;
    overwrite)
        if ! sync_state; then
            tmux display-message 'Timer sync failed'
        elif ! is_running; then
            tmux display-message 'Session has not started.'
        else
            tmux command-prompt -p 'POMODORO:' "run-shell '$CURRENT_DIR/session-overwrite.sh \"%%\"'"
        fi
        ;;
esac
