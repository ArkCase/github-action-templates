#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

declare_missing_variables()
{
	local LINE="${1}"
	local PREFIX="${2}"
	shift 2
	while read V ; do
		if [ -v "${V}" ] ; then
			[ -n "${V}" ] || V='""'
		else
			"${@}" ${V}="\${${PREFIX}${V}}"
		fi
	done < <(envsubst -v "${LINE}")
}

extract_declarations()
{
		sed -e :a -e '/\\$/N; s/\\\n//; ta' | \
		grep -Ei '^\s*ARG\s+' | \
		sed \
			-e "s;^\s*[Aa][Rr][Gg]\(\s\+\);ARG\1;g" \
			-e "s;^\s*ARG\s;;g" | \
		grep "=" | while read line ; do
			(
				declare_missing_variables "${line}" "${VAR_PREFIX}" declare -xg
				eval "${GITHUB_ACTION_PATH}/env-declare.sh" ${line} || fail "Variable declaration error for [${line}]"
			) || return ${?}
		done
}

[ -v PRIVATE_REGISTRY ] || fail "No value for PRIVATE_REGISTRY is set!"
[ -v PUBLIC_REGISTRY ] || fail "No value for PUBLIC_REGISTRY is set!"

# Parsing out the version from the "VER" argument can be tricky if it's computed from others
# values or arguments, so let's try it with some sneaky trickery.

# We have to resort to evil black magic b/c we have to cover the edge case of
# line continuations - we have to collapse those, first... then we can find the
# ARG clauses, and finally convert them all into bash "export" clauses ... which
# we then consume (this is why redefinition is an issue, above). We use a prefix
# to avoid name clashes with read-only BASH variables which can cause the task
# to fail, and we use special SED strings to add the prefix as necessary for
# variable expansion among the arguments themselves
export VAR_PREFIX="____DOCKER_ARG____"

# It's OK to define these here ... if they get overridden below, we're happy about it.
# Otherwise, we fall back to these values to avoid failing the parse.
declare -gx "${VAR_PREFIX}PRIVATE_REGISTRY=${PRIVATE_REGISTRY}"
declare -gx "${VAR_PREFIX}PUBLIC_REGISTRY=${PUBLIC_REGISTRY}"
declare -gx "${VAR_PREFIX}BASE_REGISTRY=${PRIVATE_REGISTRY}"

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
	for R in "VER" "PORTAL_VER" "PUBLISH_MAJOR" "PUBLISH_MINOR" ; do
		# This checks for each variable and outputs its
		# value if present, or an empty string if absent
		V="${VAR_PREFIX}${R}"
		[ -v "${V}" ] && echo "${R}=${!V}" || echo "${R}="
	done

	# 3. celebrate!
	exit 0
) || fail "Failed to source the generated declarations:\n${DECLARATIONS}"
exit 0
