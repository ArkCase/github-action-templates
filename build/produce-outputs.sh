#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

WORK_DIR="$(readlink -f "${GITHUB_WORKSPACE:-.}")"

VARS=(
	authoritative_tag
	private_registry
	public_registry
	image_uri
	image_digest
	image_tag=EXACT_REVISION
	revision_prefix
	revision=REVISION_BASE_NUMBER
	revision_prerelease
	revision_metadata
)

for VAR in "${VARS[@]}" ; do
	if [[ "${VAR}" =~ ^([^=]+)=(.+)$ ]] ; then
		DST="${BASH_REMATCH[1]}"
		SRC="${BASH_REMATCH[2]}"
	else
		DST="${VAR}"
		SRC="${VAR^^}"
	fi

	[ -v "${SRC}" ] || fail "No variable [${SRC}] found for the output value [${DST}]"
	echo "${DST}=${!SRC}" >> "${GITHUB_OUTPUT}"
done
