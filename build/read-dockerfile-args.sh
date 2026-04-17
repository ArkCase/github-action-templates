#!/bin/bash

# So we can test it *REPEATEDLY*
[ -v GITHUB_ACTION_PATH ] || export GITHUB_ACTION_PATH="$(dirname "$(readlink -f "${0}")")"

. "${GITHUB_ACTION_PATH}/common.sh"

usage()
{
	echo -e "usage: ${BASH_ARGV0:-${BASH_SOURCE:-${0}}} var1 [ var2 var3 ... varN ]"
	exit 1
}

extract_declarations()
{
	local RC=0
	sed -e :a -e '/\\$/N; s/\\\n//; ta' | \
	grep -Ei '^\s*ARG\s+' | \
	sed \
		-e "s;^\s*[Aa][Rr][Gg]\(\s\+\);ARG\1;g" \
		-e "s;^\s*ARG\s;;g" | \
	/usr/bin/xargs -n1 | while read DEC ; do
		[[ "${DEC}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]] || continue
		NAME="${BASH_REMATCH[1]}"
		VALUE="${BASH_REMATCH[2]}"
		echo "${NAME}=\"${VALUE}\""
	done
	return 0
}

[ ${#} -ge 1 ] || usage

BAD=()
for VAR in "${@}" ; do
	[[ "${VAR}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)$ ]] || BAD+=( "${VAR}" )
done
[ ${#BAD[@]} -eq 0 ] || fail "Invalid variable names: [ ${BAD[@]} ]"

[ -v PRIVATE_REGISTRY ] || export PRIVATE_REGISTRY="private.registry.placeholder"
[ -v PUBLIC_REGISTRY ] || export PUBLIC_REGISTRY="public.registry.placeholder"

# Parsing out the version from the "VER" argument can be tricky if it's computed from others
# values or arguments, so let's try it with some sneaky trickery.

# It's OK to define these here ... if they get overridden below, we're happy about it.
# Otherwise, we fall back to these values to avoid failing the parse.
declare -gx "PRIVATE_REGISTRY=${PRIVATE_REGISTRY}"
declare -gx "PUBLIC_REGISTRY=${PUBLIC_REGISTRY}"
declare -gx "BASE_REGISTRY=${PRIVATE_REGISTRY}"

DECLARATIONS="$(extract_declarations 2>&1)" || fail "Failed to extract the ARG declarations (rc=${?}): ${DECLARATIONS}"

#
# This should yield the values we want!
#
# We do it in a subshell so we can catch any errors from the source command,
# and from there output something sensible that can help with troubleshooting
#
# The error message from the source will include a line number which can be
# matched to the output for troubleshooting
(
	# 1. apply the declarations
	source <(echo "${DECLARATIONS}" | sed -e 's;^;export ;g')

	# 2. output the variable declarations we're interested in
	for R in "${@}" ; do
		# This checks for each variable and outputs its
		# value if present, or an empty string if absent
		[ -v "${R}" ] && echo "${R}=${!R}" || echo "${R}="
	done

	# 3. celebrate!
	exit 0
) || fail "Failed to source the generated declarations:\n${DECLARATIONS}"
exit 0
