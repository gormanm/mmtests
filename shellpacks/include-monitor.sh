. $SCRIPTDIR/shellpacks/user-hooks.sh

monitor_pre_hook() {
	call_user_hooks pre $@
}

monitor_post_hook() {
	call_user_hooks post $@
}

