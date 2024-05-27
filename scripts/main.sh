#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND=$1

init_db(){
    sqlite3 $HOME/.tmux-pomo.db "
        CREATE TABLE session_log(date text, start_time integer, deadline_time, end_time integer,  title text, current_flag integer);
        "
}

insert_end_time(){
    local CURRENT_UNIXTIME=$(date +%s)
    sqlite3 $HOME/.tmux-pomo.db "
        UPDATE session_log SET end_time = $CURRENT_UNIXTIME WHERE current_flag = 1;
        "
    # カレントフラグを全て落とす
    sqlite3 $HOME/.tmux-pomo.db "UPDATE session_log SET current_flag = 0 WHERE current_flag = 1;"
}

get_all_session_log(){
    sqlite3 $HOME/.tmux-pomo.db "SELECT * FROM session_log;"
}

get_time(){
    local SESSION_FLAG=$(tmux show-environment -g POMODORO_SESSION_FLAG)
    if [ $SESSION_FLAG == "POMODORO_SESSION_FLAG=1" ]; then
        # セッション中は時間差分を取得
        get_current_session_time_diff
    else
        # セッション終了後
        echo "finished"
    fi
}

get_current_session_time_diff(){
    local DEADLINE_UNIXTIME=$(tmux show-environment -g POMODORO_DEADLINE_UNIXTIME | sed 's/POMODOR_DEADLINE_UNIXTIME=//')
    local CURRENT_UNIXTIME=$(date +%s)

    local DIFF=$(( $DEADLINE_UNIXTIME - $CURRENT_UNIXTIME ))

    if [ $DIFF -lt 0 ];then
        # 残り時間が0以下ならセッションを終了
        end_session
    else
        # 残り時間が1以上なら残り秒数を表示
        echo $DIFF | gawk '{print strftime("%M:%S",$1)}'
    fi
}

get_current_session_title(){
    local TITLE=$(tmux show-environment -g POMODORO_SESSION_TITLE | sed 's/POMODORO_SESSION_TITLE=//')
    echo $TITLE
}

end_session(){
    tmux display-message "POMODORO finished!!!"
    tmux clock
    insert_end_time

    # ステータスバーの更新間隔を15秒
    tmux set -g status-interval 15
    # TMUX変数からセッションフラグを落とす
    tmux set-environment -g POMODORO_SESSION_FLAG 0
    # TMUXを更新
    tmux refresh-client -S
}

stop_session(){
    local SESSION_FLAG=$(tmux show-environment -g POMODORO_SESSION_FLAG)
    if [ $SESSION_FLAG == "POMODORO_SESSION_FLAG=0" ]; then
        # セッション中なら警告して終了
        tmux display-message "Session has not started."
        exit 0
    fi
    tmux display-message "POMODORO stoped!!!"
    insert_end_time

    # ステータスバーの更新間隔を15秒
    tmux set -g status-interval 15
    # TMUX変数でセッションフラグを落とす
    tmux set-environment -g POMODORO_SESSION_FLAG 0
    tmux refresh-client -S
}

start_session(){
    local SESSION_FLAG=$(tmux show-environment -g POMODORO_SESSION_FLAG)
    if [ $SESSION_FLAG == "POMODORO_SESSION_FLAG=1" ]; then
        # セッション中なら警告して終了
        tmux display-message "Session has already started."
        exit 0
    fi

    # TMUX run-shellの引数でセッション名を指定
    tmux command-prompt -p "POMODORO:" "run-shell '$CURRENT_DIR/session-init.sh %%'"
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

main(){
    [ ! -f $HOME/.tmux-pomo.db ] && init_db

    if [ "$COMMAND" = "start" ]; then
        start_session
    elif [ "$COMMAND" == "stop" ]; then
        stop_session
    elif [ "$COMMAND" == "time" ]; then
        get_time
    elif [ "$COMMAND" == "all" ]; then
        get_all_session_log
    elif [ "$COMMAND" == "color" ]; then
        get_color
    elif [ "$COMMAND" == "name" ];then
        get_current_session_title
    fi
}

main
