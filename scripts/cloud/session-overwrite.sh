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
curl -s "${ENDPOINT_URL}/api/pomo/overwrite?t=${SESSION_TITLE_ENCODED}"

tmux display-message "POMODORO started!!"
# TMUX変数でセッションタイトルを保存
tmux set-environment -g POMODORO_SESSION_TITLE "$SESSION_TITLE"
# TMUXを更新
tmux refresh-client -S
