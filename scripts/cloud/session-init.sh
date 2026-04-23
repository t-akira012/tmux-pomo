#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# セッションタイトルが引数に呼ばれていないなら終了
if [ $# -eq 0 ]; then
	tmux display-message "POMODORO: require session title."
	exit 0
fi

ENDPOINT_URL=$(jq -r .endpoint "$HOME/.config/pomo")

# コマンド引数を全てセッションタイトルとして扱う
SESSION_TITLE=$*
SESSION_TITLE_ENCODED=$(echo "$SESSION_TITLE" | jq -Rr @uri)
# 現在時刻
CURRENT_UNIXTIME=$(date +%s)

API_RESPONSE=$(curl -s "${ENDPOINT_URL}/api/pomo/new?t=${SESSION_TITLE_ENCODED}")
RESPONSED_TITLE=$(echo $API_RESPONSE | jq -r .title)

tmux display-message "POMODORO started!!"
# ステータスバーの更新間隔を1秒
tmux set -g status-interval 1
# TMUX変数でセッションフラグを立てる
tmux set-environment -g POMODORO_SESSION_FLAG 1
# TMUX変数でセッションタイトルを保存
tmux set-environment -g POMODORO_SESSION_TITLE "$RESPONSED_TITLE"
# TMUX変数でセッション開始時刻を保存
tmux set-environment -g POMODORO_START_UNIXTIME $CURRENT_UNIXTIME
# TMUXを更新
tmux refresh-client -S
