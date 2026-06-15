#!/bin/bash
#
#
set -euo pipefail

# This one is required if no other variants are identified
MINIMUM_VARIANT="main"

#
# Convert a CSV/space-separated list into a line-separated list,
# since this will make it easier to process by a 'while read'
# loop. We also fold to lowercase, as well as sorting and
# removing duplicates
#
csv_to_list()
{
	sed -e 's;\s;,;g' -e 's;,+;,;g' -e 's;^,;;g' -e 's;,$;;g' | \
		tr '[[:upper:]]' '[[:lower:]]' | \
		tr '[,[:space:]]' '\n' | \
		sed -e '/^\s*$/d' | \
		sort -u
}

invalid_variants()
{
	[ ${#} -eq 0 ] && return 0
	echo -e "Invalid variants [ ${@@Q} ]"
	exit 1
}

output_variants()
{
	#
	# This should yield the required output
	#
	local VARS="${*}"
	echo "value=$(echo -n "${VARS}" | csv_to_list | jq -Rcn '[inputs]')"
	exit 0
}

#
# If this variable is set, it's a CSV including all the variants
# that should be built. It'll be up to the build if it knows what
# to do with each of them. If the list is empty, the default
# behavior will take over.
#
if [ -n "${VARIANTS_OVERRIDE:-}" ] ; then
	echo -e "Examining VARIANTS_OVERRIDE=${VARIANTS_OVERRIDE@Q}"
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
	done < <(echo "${VARIANTS_OVERRIDE}" | csv_to_list)

	# If there are no invalids, this returns cleanly, otherwise it fails the build
	invalid_variants "${INVALID[@]}"

	output_variants "${VARIANTS[@]}" >> "${GITHUB_OUTPUT}"
fi

#
# Sanitize parameters
#

DEFAULT_VARIANTS="${MINIMUM_VARIANT}"
[ -v PARAM_VARIANTS ] || PARAM_VARIANTS=""

VARIANTS=()
INVALID=()
VARIANT_LIST="${PARAM_VARIANTS:-${DEFAULT_VARIANTS}}"
echo -e "Examining the variants from [ ${VARIANT_LIST@Q} ]"
while read VARIANT ; do
	case "${VARIANT}" in
		# The main variant requires no black magic
		main ) VARIANTS+=( "${VARIANT}" ) ;;

		# FIPS requires some checking first before accepting it
		fips ) grep -qE "^ARG\s+FIPS(=.*)?\s*$" "${GITHUB_WORKSPACE}/Dockerfile" && VARIANTS+=( "fips" ) ;;

		# TODO: Process other variants?

		* ) INVALID+=( "${VARIANT}" ) ;;
	esac
done < <(echo "${VARIANT_LIST}" | csv_to_list)

#
# If there are no invalids, this returns cleanly, otherwise it fails the build
#
invalid_variants "${INVALID[@]}"

#
# If there are no variants identified, we MUST include the "main" variant
#
[ ${#VARIANTS[@]} -gt 0 ] || VARIANTS+=( "${MINIMUM_VARIANT}" )

output_variants "${VARIANTS[@]}" >> "${GITHUB_OUTPUT}"
