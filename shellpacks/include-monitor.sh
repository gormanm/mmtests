monitor_pre_hook() {
	if [ "$MONITOR_PRE_HOOK" != "" ]; then
		echo Monitor pre-hook: $MONITOR_PRE_HOOK
		echo Monitor args: $@
		$MONITOR_PRE_HOOK $@ || die Failed to execute monitor pre-hook
	fi
}

monitor_post_hook() {
	if [ "$MONITOR_POST_HOOK" != "" ]; then
		echo Monitor post-hook: $MONITOR_POST_HOOK
		echo Monitor args: $@
		$MONITOR_POST_HOOK $@ || die Failed to execute monitor post-hook
	fi
}

monitor_cleanup_hook() {
	if [ "$MONITOR_CLEANUP_HOOK" != "" ]; then
		echo Monitor cleanup-hook: $MONITOR_CLEANUP_HOOK
		echo Monitor args: $@
		MONITOR_CLEANUP_HOOK $@ || die Failed to execute monitor cleanup-hook
	fi
}

