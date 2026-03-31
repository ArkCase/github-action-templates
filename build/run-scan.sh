#!/bin/bash
. "${GITHUB_ACTION_FILE}/common.sh"

echo "Launching the ${SCAN_TYPE^^} Scan for ${AUTHORITATIVE_TAG}..."
DOCKER_SOCKET="/var/run/docker.sock"
CMD=(
	docker run
		--rm
		--name "${SCAN_TYPE}-scanner"
		--env RESULTS_NAME="${SCAN_TYPE}${ARTIFACTS_IDENTIFIER}"
		--volume "${DOCKER_SOCKET}:${DOCKER_SOCKET}"
		--volume "${SCAN_DIR}:/results"
		"${SCANNER_IMAGE}"
		"${SCAN_TYPE}" "${AUTHORITATIVE_TAG}"
)

# Run the command!
EXIT_CODE=0
echo "Launching: ${CMD[@]@Q}"
"${CMD[@]}" || EXIT_CODE=${?}
case "${EXIT_CODE}" in
	0 | 2 ) exit 0 ;;
	* ) exit ${EXIT_CODE} ;;
esac
