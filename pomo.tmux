#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/scripts/helpers.sh"

if [ ! -f "$CURRENT_DIR/.env" ]; then
    tmux display-message 'tmux-pomo: create .env from .env.example'
    exit 1
fi
. "$CURRENT_DIR/.env"
case "${USE_LOCAL:-false}" in
    true) use=local ;;
    false)
        use=cloud
        "$CURRENT_DIR/scripts/cloud/prepare_env.sh" || exit 1
        ;;
    *) tmux display-message 'tmux-pomo: USE_LOCAL must be true or false'; exit 1 ;;
esac

tmux bind-key O run-shell "$CURRENT_DIR/scripts/${use}/main.sh overwrite"
if [ "$use" = cloud ]; then
    tmux bind-key o run-shell "$CURRENT_DIR/scripts/cloud/main.sh sync"
else
    tmux unbind-key o
fi
tmux bind-key p run-shell "$CURRENT_DIR/scripts/${use}/main.sh start"
tmux bind-key P run-shell "$CURRENT_DIR/scripts/${use}/main.sh stop"

pomo_interpolation=(
	"\#{pomo_status}"
	"\#{pomo_name}"
	"\#{pomo_color}"
)
pomo_commands=(
	"#($CURRENT_DIR/scripts/${use}/main.sh time)"
	"#($CURRENT_DIR/scripts/${use}/main.sh name)"
	"#($CURRENT_DIR/scripts/${use}/main.sh color)"
)

do_interpolation() {
	local all_interpolated="$1"
	for ((i = 0; i < ${#pomo_commands[@]}; i++)); do
		all_interpolated=${all_interpolated//${pomo_interpolation[$i]}/${pomo_commands[$i]}}
	done
	echo "$all_interpolated"
}

update_tmux_option() {
	local option=$1
	local option_value=$(get_tmux_option "$option")
	local new_option_value=$(do_interpolation "$option_value")
	set_tmux_option "$option" "$new_option_value"
}

main() {
	update_tmux_option "status-right"
	update_tmux_option "status-left"
}
main
