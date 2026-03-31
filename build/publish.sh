#!/bin/bash
. "${GITHUB_ACTION_FILE}/common.sh"

#
# BUILDS is a CSV whose values can't have spaces, so split it!
#
BUILDS=( ${BUILDS//,/ } )

#
# Iterate over the array of built artifacts, and push them
#
for BUILD in "${BUILDS[@]}" ; do
	echo "Pushing [${BUILD}] ..."
	if [ "${TAGS_ADDED:-false}" != "true" ] && [ "${AUTHORITATIVE_TAG}" != "${BUILD}" ] ; then
		echo -e "\tTagging [${AUTHORITATIVE_TAG}] as [${BUILD}] ..."
		( set -x ; exec docker tag "${AUTHORITATIVE_TAG}" "${BUILD}" ) || exit ${?}
	fi
	( set -x ; exec docker push "${BUILD}" ) || exit ${?}
done
