#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# セッションタイトルが引数に呼ばれていないなら終了
if [ $# -eq 0 ];then
    tmux display-message "POMODORO: require session title."
    exit 0
fi


# カレントフラグを全て落とす
sqlite3 $HOME/.tmux-pomo.db "UPDATE session_log SET current_flag = 0 WHERE current_flag = 1;"

# コマンド引数を全てセッションタイトルとして扱う
SESSION_TITLE=$*
# 今日
TODAY=$(date +"%Y%m%d")
# 現在時刻
CURRENT_UNIXTIME=$(date +%s)
# セッション継続時間 秒
SESSION_DURATION_TIME=$(( 15 * 60 ))
# セッション終了予定時刻
DEADLINE_UNIXTIME=$(( $CURRENT_UNIXTIME + $SESSION_DURATION_TIME ))
# SQLiteにセッションログ追加
sqlite3 $HOME/.tmux-pomo.db "
    INSERT INTO session_log values($TODAY, $CURRENT_UNIXTIME, $DEADLINE_UNIXTIME, NULL ,'$SESSION_TITLE', 1);
    "

tmux display-message "POMODORO started!!"
# ステータスバーの更新間隔を1秒
tmux set -g status-interval 1
# TMUX変数でセッションフラグを立てる
tmux set-environment -g POMODORO_SESSION_FLAG 1
# TMUX変数でセッションタイトルを保存
tmux set-environment -g POMODORO_SESSION_TITLE $SESSION_TITLE
# TMUX変数でセッション終了予定時刻を保存
tmux set-environment -g POMODORO_DEADLINE_UNIXTIME $DEADLINE_UNIXTIME
# TMUXを更新
tmux refresh-client -S
