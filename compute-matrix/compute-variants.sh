#!/bin/bash
#
#
set -euo pipefail

CANDIDATE_VARIANTS=( "main" )

#
# See if this container build cares whether there's FIPS
# anywhere or not ...
#
grep -qE "^ARG\s+FIPS(=.*)?\s*$" "${WORK_DIR}/Dockerfile" && CANDIDATE_VARIANTS+=( "fips" )

# TODO: Compute other variants?

#
# Make sure we have no duplicates
#
readarray -t VARIANTS < <(
	(
		echo "main"
		for V in "${CANDIDATE_VARIANTS[@],,}" ; do
			# Quick trim
			V="$(echo ${V})"
			[ -n "${V}" ] || continue
			[ "${V}" != "all" ] || continue
			[[ "${V}" =~ ^[^[:space:]]+$ ]] || continue
			echo "${V}"
		done
	) | sort -u | sed -e '/^\s*$/d'
)

# This should yield the required output
echo "value=[${VARIANTS[@]@Q}]" | tr ' ' ',' | tr "'" '"' >> "${GITHUB_OUTPUT}"
exit 0
