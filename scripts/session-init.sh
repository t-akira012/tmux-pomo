#!/usr/bin/env bash

tmux set-environment -g POMO_SESSION_NAME $1
tmux set-environment -g POMO_START_TIME $(date +%s)
tmux display-message "POMODORO started!!"
