#!/bin/bash

set -euo pipefail

. common.sh || exit ${?}

#
# Parameters: PARAM_REVISION, PARAM_PORTAL
#
# Required: GITHUB_OUTPUT
#
CANDIDATE_VARIANTS=( "main" )

#
# See if this container build cares whether there's FIPS
# anywhere or not ...
#
grep -qE "^ARG\s+FIPS(=.*)?\s*$" Dockerfile && CANDIDATE_VARIANTS+=( "fips" )

# TODO: Compute other variants?

#
# Make sure we have no duplicates
#
readarray -t VARIANTS < <(
	(
		echo "main"
		for VARIANT in "${CANDIDATE_VARIANTS[@],,}" ; do
			# Quick trim
			VARIANT="$(echo ${VARIANT})"
			[ -n "${VARIANT}" ] || continue
			[ "${VARIANT}" != "all" ] || continue
			[[ "${VARIANT}" =~ ^[^[:space:]]+$ ]] || continue
			echo "${VARIANT}"
		done
	) | sort -u | sed -e '/^\s*$/d'
)

# This should yield the required output
echo "value=[${VARIANTS[@]@Q}]" | tr ' ' ',' | tr "'" '"' >> "${GITHUB_OUTPUT}"
exit 0
