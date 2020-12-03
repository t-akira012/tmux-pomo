#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

session_start() {
  tmux command-prompt -p "POMO:" "run-shell '$CURRENT_DIR/session-init.sh %%'"
  tmux set -g status-interval 1
  tmux refresh-client -S
}

session_finish() {
  tmux display-message "POMODORO finished!!!"
  tmux clock
  tmux set-environment -gu POMO_END_TIME
  tmux set-environment -g POMO_FINISHED $(date +%H:%M)
  tmux set-environment -g POMO_SESSION 0
  tmux set -g status-interval 15
  tmux refresh-client -S
  # pop_message
}
session_stop() {
  tmux display-message "POMODORO stopped."
  tmux set-environment -gu POMO_END_TIME
  tmux set-environment -g POMO_FINISHED $(date +%H:%M)
  tmux set-environment -g POMO_SESSION 0
  tmux set -g status-interval 15
  tmux refresh-client -S
  # pop_message
}

session_status() {
  # #(pomo status)
  # セッションステータスを表示する
  local POMO_SESSION=$(tmux show-environment -g POMO_SESSION)
  if [ $POMO_SESSION == "POMO_SESSION=1" ];then
    get_pomodoro_time
  else
    get_finished_text
  fi
}

get_session_name() {
  # session start で指定したセッション名を返す
  cat $HOME/.tmux-pomo
}

get_color(){
  # セッション中、セッション中でないで、status line に表示する tmux-color name を返す
  local POMO_SESSION=$(tmux show-environment -g POMO_SESSION)
  if [ $POMO_SESSION == "POMO_SESSION=1" ];then
    echo "brightred"
  else
    echo "green"
  fi
}

get_pomodoro_time(){
  # 残り時間が0以下なら、session_finish に飛ぶ
  # 残り時間があるなら、残り時間を秒単位で表示
  local END_TIME=$(tmux show-environment -g POMO_END_TIME | sed 's/POMO_END_TIME=//g')
  local CURRENT_TIME=$(date +%s)
  local DIFFRENT=$(echo $(( $END_TIME - $CURRENT_TIME )))
  if [ $DIFFRENT -lt 0 ]; then
    session_finish
  else
    local T=$(echo $DIFFRENT | awk '{print strftime("%M:%S",$1)}')
    echo "$T"
  fi
}

get_finished_text(){
    # 終業時間を表示
    local FINISHED=$(tmux show-environment -g POMO_FINISHED | sed 's/POMO_FINISHED=//g')
    # echo tmux
    echo "*$POMO_FINISHED"
    # # # echo $(( ( $(date -d "18:30" +%s ) - $(date +%s) ) /60 )) | awk '{print strftime("%M:%S",$1)}'
}

pop_message(){
  if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ];then \
    /mnt/c/Windows/System32/cmd.exe /c "echo Pomodoro Finished!! > %TEMP%\PomodoroFinished.txt && notepad.exe %TEMP%\PomodoroFinished.txt"
  fi
}

main() {
  case $1 in
    "start")  session_start;;
    "stop")   session_stop;;
    "finish") session_finish;;
    "status") session_status;;
    "name")   get_session_name;;
    "color")  get_color;;
    *) :;;
  esac
}

main $1
