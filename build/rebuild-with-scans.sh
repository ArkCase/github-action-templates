#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

cleanup()
{
	doing "Cleaning up the scan results..."
	rm -rf "${SCAN_TGT_DIR}" "${FILE_LIST}" &>/dev/null
	[ -v DOCKERFILE ] && rm -f "${DOCKERFILE}" &>/dev/null
	[ -v SECURITY_REPORTS_BUNDLE ] && rm -f "${SECURITY_REPORTS_BUNDLE}" &>/dev/null
	[ -v BACKUP_TAG ] && docker image rm "${BACKUP_TAG}" &>/dev/null
}
trap cleanup EXIT

echo "Attaching scan results to ${AUTHORITATIVE_TAG}..."

#
# BUILDS is a CSV whose values can't have spaces, so split it!
#
BUILDS=( ${BUILDS//,/ } )

#
# Compute the list of reports to be added
#
FILE_LIST="security-reports.list.${SCAN_ID}"
(
	cd "${SCAN_TGT_DIR}"
	find . -mindepth 1 -maxdepth 1 -type f -name "${COMP_REPORT_PATTERN##*/}"
	find . -mindepth 1 -maxdepth 1 -type f -name "${VULN_REPORT_PATTERN##*/}"
) | sort | cut -c3- > "${FILE_LIST}"

if [ $(wc -l < "${FILE_LIST}") -gt 0 ] ; then
	SECURITY_REPORTS_BUNDLE="security-reports-${SCAN_ID}.tar.gz"
	tar -C "${SCAN_TGT_DIR}" -czvf "${SECURITY_REPORTS_BUNDLE}" --files-from="${FILE_LIST}"

	BACKUP_TAG="${AUTHORITATIVE_TAG}-bak"
	echo "Reports bundle ready! Creating a backup tag (${BACKUP_TAG}) ..."
	run docker tag "${AUTHORITATIVE_TAG}" "${BACKUP_TAG}" || exit ${?}

	#
	# Create a new Dockerfile including the reports tarfile
	#
	DOCKERFILE="Dockerfile.with-reports.${SCAN_ID}"
	cat <<-EOF > "${DOCKERFILE}"
	FROM "${AUTHORITATIVE_TAG}"
	COPY --chown=root:root --chmod=0444 "${SECURITY_REPORTS_BUNDLE}" "/security-reports.tar.gz"
	EOF

	#
	# This time we add all the tags up front, since this will
	# no longer be scanned and OSCAP won't puke on our build
	#
	echo "Computing extra tags ..."
	EXTRA_TAGS=()
	for BUILD in "${BUILDS[@]}" ; do
		[ "${AUTHORITATIVE_TAG}" == "${BUILD}" ] || EXTRA_TAGS+=( --tag "${BUILD}" )
	done

	#
	# No build args needed here b/c we don't need'em
	#
	RC=0
	run docker build --file "${DOCKERFILE}" --tag "${AUTHORITATIVE_TAG}" "${EXTRA_TAGS[@]}" . || RC=${?}
	[ ${RC} -ne 0 ] && exit ${RC}
else
	warn "No scan results found, so no extra build was done"

	#
	# This time we add all the tags up front, since this will
	# no longer be scanned and OSCAP won't puke on our build
	#
	echo "Computing extra tags ..."
	for BUILD in "${BUILDS[@]}" ; do
		[ "${AUTHORITATIVE_TAG}" == "${BUILD}" ] || run docker tag "${AUTHORITATIVE_TAG}" "${BUILD}"
	done
fi

to_env TAGS_ADDED="true"
