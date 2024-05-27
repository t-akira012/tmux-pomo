#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND=$1

init_db(){
    sqlite3 $HOME/.tmux-pomo.db "
        CREATE TABLE session_log(date text, start_time integer, deadline_time, end_time integer,  title text, current_flag integer);
        "
}

bluk_change_current_flag(){
    sqlite3 $HOME/.tmux-pomo.db "
        UPDATE session_log SET current_flag = 0 WHERE current_flag = 1;
        "
}

insert_end_time(){
    local CURRENT_UNIXTIME=$(date +%s)
    sqlite3 $HOME/.tmux-pomo.db "
        UPDATE session_log SET end_time = $CURRENT_UNIXTIME WHERE current_flag = 1;
        "
    bluk_change_current_flag
}

get_all_session_log(){
    sqlite3 $HOME/.tmux-pomo.db "SELECT * FROM session_log;"
}

get_current_session_time_diff(){
    local DEADLINE_UNIXTIME=$(sqlite3 $HOME/.tmux-pomo.db "SELECT deadline_time FROM session_log WHERE current_flag = 1;")
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
    local TITLE=$(sqlite3 $HOME/.tmux-pomo.db "SELECT TITLE FROM session_log WHERE current_flag = 1;")
    echo $TITLE
}

end_session(){
    tmux display-message "POMODORO finished!!!"
    tmux clock
    insert_end_time

    # ステータスバーの更新間隔を15秒
    tmux set -g status-interval 15
    # TMUX変数でセッションフラグを落とす
    tmux set-environment -g POMODORO_SESSION_FLAG 0
    # TMUXを更新
    tmux refresh-client -S
}

stop_session(){
    tmux display-message "POMODORO stoped!!!"
    insert_end_time

    # ステータスバーの更新間隔を15秒
    tmux set -g status-interval 15
    # TMUX変数でセッションフラグを落とす
    tmux set-environment -g POMODORO_SESSION_FLAG 0
    tmux refresh-client -S
}

start_session(){
    bluk_change_current_flag
    # TMUX run-shellの引数でセッション名を指定
    tmux command-prompt -p "POMO:" "run-shell '$CURRENT_DIR/session-init.sh %%'"
    tmux display-message "POMODORO started!!"

    # ステータスバーの更新間隔を1秒
    tmux set -g status-interval 1
    # TMUX変数でセッションフラグを立てる
    tmux set-environment -g POMODORO_SESSION_FLAG 1
    # TMUXを更新
    tmux refresh-client -S
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
        get_current_session_time_diff
    elif [ "$COMMAND" == "all" ]; then
        get_all_session_log
    elif [ "$COMMAND" == "color" ]; then
        get_color
    else
        get_current_session_title
    fi
}

main
