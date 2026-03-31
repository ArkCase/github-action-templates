#!/bin/bash

set -euo pipefail

if [ -z "${GITHUB_ACTION_PATH:-}" ] ; then
	THIS_SCRIPT="$(readlink -f "${BASH_ARGV0:${BASH_SOURCE:-${0}}}")"
	export GITHUB_ACTION_PATH="$(dirname "${THIS_SCRIPT}")"
fi

# If there's no work directory, put it in the same directory as the action
[ -n "${WORK_DIR:-}" ] || export WORK_DIR="${GITHUB_ACTION_PATH}"

# If there's no pre-defined environment file, put it in the work directory
[ -n "${ENV_FILE:-}" ] || export ENV_FILE="${WORK_DIR}/.env"

. "${ENV_FILE}"

# Iterate over the array of built artifacts, and push them
for BUILD in "${BUILDS[@]}" ; do
	echo "Pushing [${BUILD}] ..."
	if [ "${TAGS_ADDED:-false}" != "true" ] && [ "${AUTHORITATIVE_TAG}" != "${BUILD}" ] ; then
		echo -e "\tTagging [${AUTHORITATIVE_TAG}] as [${BUILD}] ..."
		( set -x ; exec docker tag "${AUTHORITATIVE_TAG}" "${BUILD}" ) || exit ${?}
	fi
	( set -x ; exec docker push "${BUILD}" ) || exit ${?}
done
