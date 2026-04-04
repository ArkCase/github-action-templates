#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

#
# The scans have been done, time to harvest the results
#

cleanup()
{
	docker volume rm "${SCAN_VOL}" &>/dev/null
}

trap cleanup EXIT

#
# Let's now do the deed!
#
CMD=(
	docker run
		--rm
		--name "recover-${SCAN_VOL}"
		--volume "${SCAN_VOL}:/results"
		--workdir "/results"
		--interactive
		--user 0
		debian
		tar -czf - .
)

"${CMD[@]}" | tar -C "${SCAN_TGT_DIR}" -xzvf -
