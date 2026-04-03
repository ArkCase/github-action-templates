#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

#
# Determine if we're doing local development or not
#
if [ -v ACT ] ; then
	LOCAL_DEV="${ACT,,}"
elif [ -v LOCAL_DEV ] ; then
	LOCAL_DEV="${LOCAL_DEV,,}"
else
	LOCAL_DEV="false"
fi

#
# Sanitize the value!
#
case "${LOCAL_DEV}" in
	true ) ;;
	* ) LOCAL_DEV="false" ;;
esac
to_env LOCAL_DEV

#
# Only compute these if in local development mode
#
if is_local_dev ; then
	LOCAL_PUBLISH="false"
	[ -n "${LOCAL_REGISTRY:-}" ] && [ -n "${LOCAL_REGISTRY_USERNAME:-}" ] && [ -n "${LOCAL_REGISTRY_PASSWORD:-}" ] && LOCAL_PUBLISH="true"
	to_env LOCAL_REGISTRY LOCAL_REGISTRY_USERNAME LOCAL_REGISTRY_PASSWORD LOCAL_PUBLISH
fi

#
# Define these early on
#
to_env PRIVATE_REGISTRY="${LOCAL_REGISTRY:-}" PUBLIC_REGISTRY="${LOCAL_REGISTRY:-}"
