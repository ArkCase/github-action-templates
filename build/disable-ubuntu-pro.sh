#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

sudo pro detach --assume-yes \
	&& ok "Ubuntu Pro detached!" \
	|| fail "Failed to detach from Ubuntu Pro (rc=${?})"
exit 0
