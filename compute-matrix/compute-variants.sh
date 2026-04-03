#!/bin/bash
#
#
set -euo pipefail

if [ -n "${VARIANTS_OVERRIDE:-}" ] ; then
	# If this variable is set, it's a CSV including all the variants
	# that should be built. It'll be up to the build if it knows what
	# to do with each of them. If the list is empty, the default
	# behavior will take over.
	VARIANTS=()
	INVALID=()
	RE_VARIANT="[a-z0-9]([-a-z0-9]*[a-z0-9])?"
	while read VARIANT ; do
		# Variant names may only be comprised of lowercase letters,
		# numbers, and dashes. They must start and end with a letter
		# or number, and may not contain double dashes anywhere in
		# the sequence
		if [[ "${VARIANT}" =~ ^${RE_VARIANT}$ ]] && [[ ! "${VARIANT}" =~ -- ]] ; then
			VARIANTS+=( "${VARIANT}" )
		else
			INVALID+=( "${VARIANT}" )
		fi
	done < <(echo "${VARIANTS_OVERRIDE}" | tr '[[:upper:]]' '[[:lower:]]' | tr '[,[:space:]]' '\n' | sed -e '/^\s*$/d' | sort -u)

	if [ ${#INVALID[@]} -gt 0 ] ; then
		echo -e "Invalid variants [ ${INVALID[@]@Q} ] found in VARIANTS_OVERRIDE=${VARIANTS_OVERRIDE@Q}"
		exit 1
	fi

	# Spit out the specific list of variants the user
	# wants to build, with no additional considerations
	echo "value=[${VARIANTS[@]@Q}]" | tr ' ' ',' | tr "'" '"' >> "${GITHUB_OUTPUT}"
	exit 0
fi

#
# The main variant - ever present!
#
CANDIDATE_VARIANTS=( "main" )

#
# See if this container build cares whether there's FIPS
# anywhere or not ...
#
grep -qE "^ARG\s+FIPS(=.*)?\s*$" "${GITHUB_WORKSPACE}/Dockerfile" && CANDIDATE_VARIANTS+=( "fips" )

# TODO: Compute other variants? Maybe generalize the process?

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
