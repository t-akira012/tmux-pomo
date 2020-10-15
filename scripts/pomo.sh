#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

session_start() {
  tmux command-prompt -p "POMO:" "run-shell '$CURRENT_DIR/session-init.sh %1'"
}

session_stop() {
  tmux display-message "POMODORO stopped."
  tmux set-environment -gu POMO_START_TIME
  tmux refresh-client -S
}

get_session_time() {
  local CURRENT_TIME=$(date +%s)
  local START_TIME=$(tmux show-environment -g POMO_START_TIME | sed 's/POMO_START_TIME=//g')
  local DIFFRENT=$(( $CURRENT_TIME - $START_TIME ))
  echo $DIFFRENT | awk '{print strftime("%M:%S",$1)}'
}

get_session_name() {
  tmux show-environment -g POMO_SESSION_NAME
  local SESSION_NAME=$(tmux show-environment -g POMO_SESSION_NAME | sed 's/POMO_SESSION_NAME=//g')
  echo $SESSION_NAME
}


main() {
  case $1 in
    "start") session_start;;
    "stop")  session_stop;;
    "time")  get_session_time;;
    "name")  get_session_name;;
    *) :;;
  esac
}

main $1
