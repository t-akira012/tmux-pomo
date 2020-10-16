#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

session_start() {
  tmux command-prompt -p "POMO:" "run-shell '$CURRENT_DIR/session-init.sh %%'"
}

session_finish() {
  tmux display-message "POMODORO finished!!!"
  tmux clock
  tmux set-environment -gu POMO_END_TIME
  tmux set-environment -g POMO_FINISHED $(date +%H:%M)
  tmux set-environment -g POMO_SESSION 0
  tmux refresh-client -S
}
session_stop() {
  tmux display-message "POMODORO stopped."
  tmux set-environment -gu POMO_END_TIME
  tmux set-environment -g POMO_FINISHED $(date +%H:%M)
  tmux set-environment -g POMO_SESSION 0
  tmux refresh-client -S
}

get_session_time() {
    local POMO_SESSION=$(tmux show-environment -g POMO_SESSION)
  if [ $POMO_SESSION == "POMO_SESSION=1" ];then
    local END_TIME=$(tmux show-environment -g POMO_END_TIME | sed 's/POMO_END_TIME=//g')
    local CURRENT_TIME=$(date +%s)
    local DIFFRENT=$(echo $(( $END_TIME - $CURRENT_TIME )))
    if [ $DIFFRENT -lt 0 ]; then
      session_finish
    else
      echo $DIFFRENT | awk '{print strftime("%M:%S",$1)}'
    fi
  else
    local FINISHED=$(tmux show-environment -g POMO_FINISHED | sed 's/POMO_FINISHED=//g')
    echo f:$FINISHED
  fi
}

get_session_name() {
  cat $HOME/.tmux-pomo
}

get_color(){
    local POMO_SESSION=$(tmux show-environment -g POMO_SESSION)
  if [ $POMO_SESSION == "POMO_SESSION=1" ];then
    echo "brightred"
  else
    echo "green"
  fi
}


main() {
  case $1 in
    "start") session_start;;
    "stop")  session_stop;;
    "finish")  session_finish;;
    "time")  get_session_time;;
    "name")  get_session_name;;
    "color")  get_color;;
    *) :;;
  esac
}

main $1
