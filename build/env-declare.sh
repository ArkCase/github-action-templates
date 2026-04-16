#!/bin/bash

[ -v VAR_PREFIX ] || VAR_PREFIX=""

for ENV in "${@}" ; do
	[[ "${ENV}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]] || continue
	NAME="${BASH_REMATCH[1]}"
	VALUE="${BASH_REMATCH[2]}"
	echo "${VAR_PREFIX}${NAME}=\"${VALUE//\"/\\\"}\""
done
