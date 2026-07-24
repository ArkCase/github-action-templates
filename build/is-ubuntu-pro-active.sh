#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

STATUS="$(sudo pro status --format json 2>&1)" || fail "Failed to query the Ubuntu Pro status (rc=${?}): ${STATUS}"

ATTACHED="$(echo -n "${STATUS}" | jq -r .attached 2>&1)" || fail "Failed to parse the 'attached' result from the given status:\n${STATUS}"
SIMULATED="$(echo -n "${STATUS}" | jq -r .simulated 2>&1)" || fail "Failed to parse the 'simulated' result from the given status:\n${STATUS}"

[ "${ATTACHED,,}" == "true" ] && [ "${ATTACHED,,}" != "${SIMULATED,,}" ] && exit 0
exit 1
