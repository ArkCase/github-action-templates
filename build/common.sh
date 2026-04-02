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
	local SUFFIX=""
	[ -v PARALLEL_ID ] && SUFFIX="|${!PARALLEL_ID}"
	echo -e "$(timestamp) [${$}${SUFFIX}]: ${@}"
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

waiting()
{
	say "⏳ ${@}"
}

sleeping()
{
	say "💤 ${@}"
}

running()
{
	say "🚀 ${@}"
}

eyes()
{
	say "👀 ${@}"
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
	exit ${EXIT_CODE:-1}
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

is_envvar()
{
	local VAR="${1:-}"
	[[ "${VAR}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)$ ]] || return 1
	return 0
}

has_value()
{
	local DECL="${1}"
	[[ "${DECL}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]] || return 1
	return 0
}

to_env()
{
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

is_local_dev()
{
	[ "${LOCAL_DEV:-}" == "true" ] || return 1
	return 0
}
