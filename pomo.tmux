#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. $CURRENT_DIR/scripts/helpers.sh

tmux bind-key O run-shell "$CURRENT_DIR/scripts/cloud.sh overwrite"
tmux bind-key o run-shell "$CURRENT_DIR/scripts/cloud.sh sync"
tmux bind-key p run-shell "$CURRENT_DIR/scripts/cloud.sh start"
tmux bind-key P run-shell "$CURRENT_DIR/scripts/cloud.sh stop"

pomo_interpolation=(
	"\#{pomo_status}"
	"\#{pomo_name}"
	"\#{pomo_color}"
)
pomo_commands=(
	"#($CURRENT_DIR/scripts/cloud.sh time)"
	"#($CURRENT_DIR/scripts/cloud.sh name)"
	"#($CURRENT_DIR/scripts/cloud.sh color)"
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
