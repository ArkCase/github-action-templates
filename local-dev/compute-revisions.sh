#!/bin/bash

set -euo pipefail

. common.sh || exit ${?}

#
# Parameters: PARAM_REVISION, PARAM_PORTAL
#
# Required: GITHUB_OUTPUT, GITHUB_WORKSPACE, RE_FULL_REVISION
#

# If we were given a non-empty input value for PARAM_REVISION,
# then we simply output that and call it a day. Otherwise,
# proceed with the computation. We also validate it early
# just to save computation time.
if [ -n "${PARAM_REVISION}" ] ; then
	if [[ "${PARAM_REVISION}" =~ ${RE_FULL_REVISION} ]] ; then
		echo -e "The REVISION parameter was given with the value [${PARAM_REVISION}]"
		echo "value=[${PARAM_REVISION@Q}]" | tr ' ' ',' | tr "'" '"' >> "${GITHUB_OUTPUT}"
		exit ${?}
	fi
	echo "Revision number is not valid: [${PARAM_REVISION}]"
	exit 1
fi

# Same courtesy to the portal revision even though it can't be
# processed dynamically as a matrix (this would be a BAD idea)
if [ -n "${PARAM_PORTAL}" ] && [[ ! "${PARAM_PORTAL}" =~ ${RE_FULL_REVISION} ]] ; then
	echo "The FOIA Portal version is not valid: [${PARAM_PORTAL}]"
	exit 1
fi

OUT=""
METHOD=""
FILE_NAME=".alt-revisions"
FILE="${GITHUB_WORKSPACE}/${FILE_NAME}"
SCRIPT_NAME="${FILE_NAME}.dynamic"
SCRIPT="${GITHUB_WORKSPACE}/${SCRIPT_NAME}"
if [ -f "${SCRIPT}" ] ; then
	# If there's a script called ".alt-revisions.dynamic" in the
	# root checkout directory, then we run that and its STDOUT
	# becomes the result, and is processed as if it were the content
	# of the ".alt-revisions" file (see below).
	if [ ! -x "${SCRIPT}" ] ; then
		echo "ERROR: The script [${SCRIPT_NAME}] is not executable"
		exit 1
	fi

	RC=0
	OUT="$( "${SCRIPT}" )" || RC=${?}
	if [ ${RC} -ne 0 ] ; then
		echo "ERROR: Failed to compute the alternate revisions using [${SCRIPT_NAME}] (rc=${?}): ${OUT}"
		exit ${RC}
	fi
	METHOD="${SCRIPT}"
	echo -e "The script [${SCRIPT_NAME}] produced the following (raw) revisions:\n${OUT}"
elif [ -f "${FILE}" ] ; then
	# If there's no script to do the computation, but there's a
	# file called ".alt-revisions" then each line of the file will be
	# examined.
	if [ ! -r "${FILE}" ] ; then
		echo "ERROR: The file [${FILE_NAME}] is not readable"
		exit 1
	fi

	RC=0
	OUT="$(<"${FILE}")" || RC=${?}
	if [ ${RC} -ne 0 ] ; then
		echo "ERROR: Failed to read the alternate revisions from [${FILE_NAME}] (rc=${?})"
		exit ${RC}
	fi
	METHOD="${FILE}"
	echo -e "The static file [${FILE_NAME}] produced the following (raw) revisions:\n${OUT}"
else
	echo "No dynamic revisions were computed - will use the default algorithm!"
fi

REVISIONS=()
# The output will be filtered to remove comments and blank lines. The
# resulting list will be sorted using "version sort" order, ascending.
[ -n "${METHOD}" ] && readarray -t REVISIONS < <(echo -ne "${OUT}" | sed -e 's;#.*$;;g' -e '/^\s*$/d' | sort -V -u)

# Did we find any revisions?
if [ ${#REVISIONS[@]} -gt 0 ] ; then
	# However we got the revisions, we will validate every single one
	# against the regex. If there are any invalid values, this is an
	# error condition and it will fail the job and be reported, as well
	# as the means by which the invalid revision was obtained.
	#
	# If the above methods yielded any valid revisions, these are
	# returned in the format "value=[ json-array ]". If they did not
	# yield any revisions (i.e. no invalid or non-blank revisions), then
	# the default list of "*" is produced to allow the default algorithm
	# to take over and work as normal.

	METHOD="$(basename "${METHOD}")"
	for REVISION in "${REVISIONS[@]}" ; do
		# If this is a valid revision number, keep it and check the next one!
		[ -n "${REVISION}" ] && [[ "${REVISION}" =~ ${RE_FULL_REVISION} ]] && continue

		# This is an invalid revision number ... go kablooey!
		echo "ERROR: Invalid revision number [${REVISION}] obtained via [${METHOD}]"
		exit 1
	done
else
	# No revisions found ... use the default algorithm!
	REVISIONS=( "*" )
fi

# This should yield the required output
echo "value=[${REVISIONS[@]@Q}]" | tr ' ' ',' | tr "'" '"' >> "${GITHUB_OUTPUT}"
exit 0
