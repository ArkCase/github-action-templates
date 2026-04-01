#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

#
# Determine if we're doing local development or not
#
LOCAL_DEV="false"
LOCAL_PUBLISH="false"
if [ -n "${LOCAL_REGISTRY:-}" ] ; then
	LOCAL_DEV="true"
	[ -n "${LOCAL_REGISTRY_USERNAME:-}" ] && [ -n "${LOCAL_REGISTRY_PASSWORD:-}" ] && LOCAL_PUBLISH="true"
fi
to_env LOCAL_DEV LOCAL_REGISTRY LOCAL_REGISTRY_USERNAME LOCAL_REGISTRY_PASSWORD LOCAL_PUBLISH

#
# Define these early on
#
to_env PRIVATE_REGISTRY="${LOCAL_REGISTRY}" PUBLIC_REGISTRY="${LOCAL_REGISTRY}"
