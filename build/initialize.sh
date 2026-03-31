#!/bin/bash
. "${GITHUB_ACTION_FILE}/common.sh"

#
# Clear out the environment file!
#
: > "${ENV_FILE}"

TIMESTAMP="$(date -u +%Y%m%d%H%M%S)"
echo "export TIMESTAMP=${TIMESTAMP@Q}" | to_env
echo "TIMESTAMP=${TIMESTAMP@Q}"

# If we're not given an explicit revision, and the
# matrix revision is NOT the value "*", then this means
# we have to build for a specific revision, and thus
# we treat the value from MATRIX_REVISION as if it were
# a parameter given to us on invocation.
[ -z "${PARAM_REVISION}" ] && [ "${MATRIX_REVISION}" != "*" ] && PARAM_REVISION="${MATRIX_REVISION}"

echo "export PARAM_REVISION=${PARAM_REVISION@Q}" | to_env
echo "PARAM_REVISION=${PARAM_REVISION@Q}"

echo "export PARAM_PORTAL=${PARAM_PORTAL@Q}" | to_env
echo "PARAM_PORTAL=${PARAM_PORTAL@Q}"

export VARIANT="${MATRIX_VARIANT}"
echo "export VARIANT=${VARIANT@Q}" | to_env
echo "VARIANT=${VARIANT@Q}"

[ "${MATRIX_REVISION}" == "*" ] \
	&& REVISION_SUFFIX="all" \
	|| REVISION_SUFFIX="${MATRIX_REVISION}"

# See if we have a revision-specific file with build arguments to provide

# By processing the candidates in a specific order we can add precedence
# because later-defined arguments will override earlier-defined ones
CANDIDATES=(
	"all/all"
	"${VARIANT}/all"
)
[ -n "${REVISION_SUFFIX}" ] && [ "${REVISION_SUFFIX}" != "all" ] && \
	CANDIDATES+=( "all/${REVISION_SUFFIX}" "${VARIANT}/${REVISION_SUFFIX}" )

ARGS_TEMP="$(mktemp --tmpdir="${GITHUB_ACTION_PATH}" ".build-args-XXXXXX.tmp")"
ARGS_DIR="${WORK_DIR}/.build-args"
for CANDIDATE in "${CANDIDATES[@]}" ; do
	[[ "${CANDIDATE}" =~ ^(.*)/(.*)$ ]] || continue

	VARIANT="${BASH_REMATCH[1]}"
	REVISION_SUFFIX="${BASH_REMATCH[2]}"

	SCRIPT_NAME="${VARIANT}/dynamic-${REVISION_SUFFIX}"
	SCRIPT="${ARGS_DIR}/${SCRIPT_NAME}"

	FILE_NAME="${VARIANT}/static-${REVISION_SUFFIX}"
	FILE="${ARGS_DIR}/${FILE_NAME}"

	BUILD_ARGS=""
	RC=0
	if [ -f "${SCRIPT}" ] ; then
		if [ -x "${SCRIPT}" ] ; then
			echo -e "ERROR: The build arguments script [${SCRIPT_NAME}] is not executable"
			exit 1
		fi
		BUILD_ARGS="$( set -o allexport ; . "${ARGS_TEMP}" ; "${SCRIPT}" )" || RC=${?}
		if [ ${RC} -ne 0 ] ; then
			echo -e "ERROR: Failed to compute the build arguments from [${SCRIPT_NAME}] (rc=${RC}): ${BUILD_ARGS}"
			exit 1
		fi
		echo -e "The script [${SCRIPT_NAME}] produced the following (raw) build arguments:"
		echo -e "--------------------------------------------------------------------------------"
		echo -e "${BUILD_ARGS}"
		echo -e "--------------------------------------------------------------------------------"
	elif [ -f "${FILE}" ] ; then
		if [ -x "${FILE}" ] ; then
			echo -e "ERROR: The build arguments file [${FILE_NAME}] is not readable"
			exit 1
		fi
		BUILD_ARGS="$(<"${FILE}")" || RC=${?}
		if [ ${RC} -ne 0 ] ; then
			echo -e "ERROR: Failed to read the build arguments from [${FILE_NAME}] (rc=${RC})"
			exit 1
		fi
		echo -e "The file [${FILE_NAME}] produced the following (raw) build arguments:"
		echo -e "--------------------------------------------------------------------------------"
		echo -e "${BUILD_ARGS}"
		echo -e "--------------------------------------------------------------------------------"
	else
		continue
	fi

	# The output must be a list of key-value pairs. Each key will be renamed
	# as BUILD_ARG_${KEY} and will be set as a build argument via docker's
	# --build-arg ${KEY}=${VALUE} mechanism.
	while read VAR ; do
		[[ "${VAR}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]] || continue
		KEY="BUILD_ARG_${BASH_REMATCH[1]}"
		VALUE="${BASH_REMATCH[2]}"

		# Remove prior values, and buffer them
		PREV="$(grep -v "^${KEY}=" "${ARGS_TEMP}")" || true
		(
			# Output the old values without the new value
			echo "${PREV}"
			# Output the new value
			echo "${KEY}=${VALUE@Q}"
		) | sort | sed -e '/^\s*$/d' > "${ARGS_TEMP}"
	done <<< "${BUILD_ARGS}"
done

# Now we output the variables, only keeping the last definition
# (this may be unnecessary, but is a good safety measure anyway)
while read VAR ; do
	VAL="$(grep "^${VAR}=" "${ARGS_TEMP}" | tail -1)"
	echo "export ${VAL}" | to_env
	echo "${VAL}"
done < <( sed -e 's;=.*$;;g' < "${ARGS_TEMP}" | sort -u )
