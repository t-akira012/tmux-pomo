#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/api.sh" || exit 1
umask 077

retain_memo() {
    tmux display-message "Memo $1; file retained: $memo_dir/memo.md"
    exit 1
}

if [[ ${1:-} = edit ]]; then
    memo_dir=$2
    nvim "$memo_dir/memo.md" || retain_memo 'editor failed'
    if cmp -s "$memo_dir/original.md" "$memo_dir/memo.md"; then
        rm -rf "$memo_dir"
        exit 0
    fi
    jq -n --rawfile text "$memo_dir/memo.md" '{text:$text}' > "$memo_dir/request.json" || retain_memo 'encoding failed'
    pomo_request PUT memo '' "$memo_dir/request.json" > /dev/null || retain_memo 'upload failed'
    rm -rf "$memo_dir"
    tmux display-message 'Memo saved to R2'
    exit 0
fi

command -v nvim >/dev/null 2>&1 || { tmux display-message 'Memo requires nvim'; exit 1; }
memo_tmp_root=${TMPDIR:-/tmp}
memo_dir=$(mktemp -d "${memo_tmp_root%/}/tmux-pomo-memo.XXXXXX") || exit 1
if ! pomo_request GET memo > "$memo_dir/response.json" ||
   ! jq -e 'type == "object" and (.text | type == "string")' "$memo_dir/response.json" > /dev/null ||
   ! jq -j '.text' "$memo_dir/response.json" > "$memo_dir/memo.md"; then
    rm -rf "$memo_dir"
    tmux display-message 'Memo pull failed'
    exit 1
fi
cp "$memo_dir/memo.md" "$memo_dir/original.md" || retain_memo 'preparation failed'
tmux display-popup -E -w 90% -h 90% bash "$CURRENT_DIR/memo.sh" edit "$memo_dir"
