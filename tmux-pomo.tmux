#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${CURRENT_DIR}/scripts/helpers.sh"


readonly pomo_start_key="$(get_tmux_option "@pomo-start-key" "p")"
readonly pomo_clear_key="$(get_tmux_option "@pomo-clear-key" "P")"
readonly pomo_cmd="$(get_pomodoro_cmd)"

main(){
}
main

