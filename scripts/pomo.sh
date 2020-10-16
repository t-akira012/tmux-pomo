#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

session_start() {
  tmux command-prompt -p "POMO:" "run-shell '$CURRENT_DIR/session-init.sh %%'"
}

session_stop() {
  tmux display-message "POMODORO stopped!!!"
  tmux set-environment -gu POMO_END_TIME
  tmux set-environment -g POMO_FINISHED $(date +%H:%M)
  tmux set-environment -g POMO_SESSION 0
  tmux refresh-client -S
}

get_session_time() {
    local POMO_SESSION=$(tmux show-environment -g POMO_SESSION)
  if [ $POMO_SESSION == "POMO_SESSION=0" ];then
    # option で指定した文字列を表示する
    local FINISHED=$(tmux show-environment -g POMO_FINISHED | sed 's/POMO_FINISHED=//g')
    echo f:$FINISHED
  else
    local END_TIME=$(tmux show-environment -g POMO_END_TIME | sed 's/POMO_END_TIME=//g')
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
  cat $HOME/.tmux-pomo
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
