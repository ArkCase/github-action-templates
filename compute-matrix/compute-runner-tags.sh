#!/bin/bash
#
#
set -euo pipefail

#
# TODO: we might add more complex logic in the future to determine
# a more sophisticated runner tagging system. For now, this is
# sufficient for our immediate and foreseeable needs.
#

TAGS=""
[ "${PARAM_LARGE_RUNNER:-}" == "true" ] && TAGS="large"

#
# Make sure we always lead with a dash
#
[ -n "${TAGS}" ] && [ "${TAGS:0:1}" != "-" ] && TAGS="-${TAGS}"

# This should yield the required output
echo "value=$(jq -cn '$ARGS.positional' --args -- "${TAGS}")" >> "${GITHUB_OUTPUT}"
exit ${?}
