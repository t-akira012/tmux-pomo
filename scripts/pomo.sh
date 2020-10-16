#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

session_start() {
  tmux command-prompt -p "POMO:" "run-shell '$CURRENT_DIR/session-init.sh %1'"
}

session_stop() {
  tmux display-message "pomodoro stopped!!!"
  tmux set-environment -gu POMO_START_TIME
  tmux refresh-client -S
}

get_session_time() {
  local END_TIME=$(tmux show-environment -g POMO_END_TIME | sed 's/POMO_END_TIME=//g')
  if [ -z $END_TIME ];then
    # option で指定した文字列を表示する
    echo tmux
  else
    local CURRENT_TIME=$(date +%s)
    local DIFFRENT=$(echo $(( $END_TIME - $CURRENT_TIME )))
    if [ $DIFFRENT -lt 0 ]; then
      session_stop
    else
      echo $DIFFRENT | awk '{print strftime("%M:%S",$1)}'
    fi
  fi
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
