#!/bin/bash

set -euo pipefail

#
# usage: timestamp
#
# Outputs the current system time in UTC, using ISO-8601
# format with nanosecond resolution
#
timestamp()
{
	/usr/bin/date -Ins -u
}

#
# usage: say [args ...]
#
# Output a message to stdout, preceded by a timestamp
#
say()
{
	echo -e "$(timestamp) [${$}]: ${@}"
}

#
# These functions are just for prettyness and convenience :)
#

doing()
{
	say "👉 ${@}"
}

ok()
{
	say "✅ ${@}"
}

warn()
{
	say "⚠️ ${@}"
}

err()
{
	say "❌ ${@}"
}

#
# usage: [EXIT_CODE=X] fail [args ...]
#
# End processing (via a call to exit) with the exit code
# ${EXIT_CODE} (defaults to 1 if not given), and outputting
# the given message using the err function.
#
fail()
{
	err "${@}"
	exit "${EXIT_CODE:-1}"
}

#
# usage: quit [args ...]
#
# End processing (via a call to exit) with the exit code
# 0, and outputting the given message using the say function.
#
quit()
{
	say "🚪 ${@}"
	exit 0
}

#
# usage: ensure_inside ROOT PATH LABEL
#
# Fail unless PATH, once all its symlinks are resolved, is either ROOT
# itself or lies within it (ROOT is resolved the same way). Paths that
# don't exist yet are resolved as far as they exist, and normalized
# lexically from there on.
#
ensure_inside()
{
	local ROOT="${1}"
	local TARGET="${2}"
	local LABEL="${3}"
	local REAL_ROOT=""
	local REAL_TARGET=""

	REAL_ROOT="$(realpath -m "${ROOT}" 2>&1)" || fail "Failed to resolve the path [${ROOT}] (rc=${?}): ${REAL_ROOT}"
	REAL_TARGET="$(realpath -m "${TARGET}" 2>&1)" || fail "Failed to resolve the ${LABEL} [${TARGET}] (rc=${?}): ${REAL_TARGET}"
	case "${REAL_TARGET}" in
		"${REAL_ROOT}" | "${REAL_ROOT}/"* ) return 0 ;;
	esac
	fail "The ${LABEL} [${TARGET}] resolves to [${REAL_TARGET}], which is outside of [${ROOT}]"
}

has_value()
{
	local DECL="${1}"
	[[ "${DECL}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]] || return 1
	return 0
}

#
# usage: to_env VAR|VAR=VALUE [...]
#
# Set the given variables both in this shell and in ${GITHUB_ENV},
# so they're available to all subsequent steps
#
to_env()
{
	local VAR=""
	local KEY=""
	local VALUE=""
	local DECL=""

	for VAR in "${@}" ; do
		# If it's a full declaration,
		if has_value "${VAR}" ; then
			KEY="${BASH_REMATCH[1]}"
			VALUE="${BASH_REMATCH[2]}"
		else
			KEY="${VAR}"
			VALUE="${!VAR:-}"
		fi
		DECL="${KEY}=${VALUE}"
		declare -xg "${DECL}"
		echo "${DECL}" >> "${GITHUB_ENV}"
	done
}
