#!/usr/bin/env bash

SESSION_NAME=$1
if [ -n "$SESSION_NAME" ];then
  echo $SESSION_NAME > $HOME/.tmux-pomo
fi
CURRENT_TIME=$(date +%s)
SESSION_TIME=$(( 15 * 60 ))
END_TIME=$(( $SESSION_TIME + $CURRENT_TIME ))
tmux set-environment -g POMO_SESSION 1
tmux set-environment -g POMO_END_TIME $END_TIME
tmux display-message "POMODORO started!!"
