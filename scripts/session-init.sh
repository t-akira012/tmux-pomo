#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
