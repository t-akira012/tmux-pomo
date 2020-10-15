#!/usr/bin/env bash

CURRENT_TIME=$(date +%s)
SESSION_TIME=$(( 15 * 60 ))
END_TIME=$(( $SESSION_TIME + $CURRENT_TIME ))
tmux set-environment -g POMO_SESSION_NAME $1
tmux set-environment -g POMO_END_TIME $END_TIME
tmux display-message "POMODORO started!!"
