#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND=$1
# ENDPOINT_URL
source $CURRENT_DIR/env

insert_end_time() {
	curl -s ${ENDPOINT_URL}/api/pomo/stop
	# TMUX変数にセッション終了時刻を保存
	tmux set-environment -g POMODORO_FINISHED_TIME $(date +%H:%M)
}

sync() {
	local CURRENT_SESSION=$(curl -s ${ENDPOINT_URL}/api/current)

	if [ "$CURRENT_SESSION" == "" ]; then
		exit 0
	else
		# ステータスバーの更新間隔を1秒
		# tmux set -g status-interval 1
		# TMUX変数でセッションフラグを立てる
		tmux set-environment -g POMODORO_SESSION_FLAG 1
		local SESSION_TITLE=$(echo $CURRENT_SESSION | jq -r '.title')
		# TMUX変数でセッションタイトルを保存
		tmux set-environment -g POMODORO_SESSION_TITLE $SESSION_TITLE
		local DEADLINE_UNIXTIME=$(echo $CURRENT_SESSION | jq -r '.deadline_time')
		# TMUX変数でセッション終了予定時刻を保存
		tmux set-environment -g POMODORO_DEADLINE_UNIXTIME $DEADLINE_UNIXTIME
	fi
}

get_time() {
	local SESSION_FLAG=$(tmux show-environment -g POMODORO_SESSION_FLAG)
	if [ $SESSION_FLAG == "POMODORO_SESSION_FLAG=1" ]; then
		# セッション中は時間差分を取得
		get_current_session_time_diff
	else
		# セッション終了後
		local FINISHED_TIME=$(tmux show-environment -g POMODORO_FINISHED_TIME | sed 's/POMODORO_FINISHED_TIME=//')
		echo $FINISHED_TIME
	fi
}

get_current_session_time_diff() {
	local DEADLINE_UNIXTIME=$(tmux show-environment -g POMODORO_DEADLINE_UNIXTIME | sed 's/POMODORO_DEADLINE_UNIXTIME=//')

	local DIFF=$(($DEADLINE_UNIXTIME - $CURRENT_UNIXTIME))

	if [ $DIFF -lt 0 ]; then
		# 残り時間が0以下ならセッションを終了
		end_session
	else
		# 残り時間が1以上なら残り秒数を表示
		echo $DIFF | gawk '{print strftime("%M:%S",$1)}'
	fi
}

get_current_session_title() {
	local TITLE=$(tmux show-environment -g POMODORO_SESSION_TITLE | sed 's/POMODORO_SESSION_TITLE=//')
	echo $TITLE
}

post_stop() {
	# ステータスバーの更新間隔を伸ばす
	# tmux set -g status-interval 15
	# TMUX変数でセッションフラグを落とす
	tmux set-environment -g POMODORO_SESSION_FLAG 0
	tmux refresh-client -S
}

end_session() {
	tmux display-message "POMODORO finished!!!"
	tmux clock
	insert_end_time
	post_stop
}

stop_session() {
	local SESSION_FLAG=$(tmux show-environment -g POMODORO_SESSION_FLAG)
	if [ $SESSION_FLAG == "POMODORO_SESSION_FLAG=0" ]; then
		# セッション中なら警告して終了
		tmux display-message "Session has not started."
		exit 0
	fi
	tmux display-message "POMODORO stoped!!!"
	insert_end_time
	post_stop
}

start_session() {
	local SESSION_FLAG=$(tmux show-environment -g POMODORO_SESSION_FLAG)
	if [ $SESSION_FLAG == "POMODORO_SESSION_FLAG=1" ]; then
		# セッション中なら警告して終了
		tmux display-message "Session has already started."
		exit 0
	fi

	# TMUX run-shellの引数でセッション名を指定
	tmux command-prompt -p "POMODORO:" "run-shell '$CURRENT_DIR/cloud-session-init.sh \"%%\"'"
}

get_color() {
	local SESSION_FLAG=$(tmux show-environment -g POMODORO_SESSION_FLAG)
	if [ $SESSION_FLAG == "POMODORO_SESSION_FLAG=1" ]; then
		# セッション中は赤
		echo "brightred"
	else
		# セッション終了後は緑
		echo "green"
	fi
}

main() {
	# グローバル変数
	CURRENT_UNIXTIME=$(date +%s)

	if [ "$COMMAND" = "start" ]; then
		start_session
	elif [ "$COMMAND" == "stop" ]; then
		stop_session
	elif [ "$COMMAND" == "sync" ]; then
		sync
	elif [ "$COMMAND" == "time" ]; then
		get_time
	elif [ "$COMMAND" == "all" ]; then
		get_all_session_log
	elif [ "$COMMAND" == "color" ]; then
		get_color
	elif [ "$COMMAND" == "name" ]; then
		get_current_session_title
	fi

	# 30秒毎にDB同期
	if [ $(($CURRENT_UNIXTIME % 30)) -eq 0 ]; then
		sync
	fi

}

main
