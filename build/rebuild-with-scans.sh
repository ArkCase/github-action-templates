#!/bin/bash
. "${GITHUB_ACTION_FILE}/common.sh"

echo "Attaching scan results to ${AUTHORITATIVE_TAG}..."

# Compute the list of reports to be added
SECURITY_REPORTS_BUNDLE="security-reports.tar.gz"
FILE_LIST="security-reports.list.${GITHUB_RUN_NUMBER}"
(
    find . -mindepth 1 -maxdepth 1 -type f -name "${COMP_REPORT_PATTERN}"
    find . -mindepth 1 -maxdepth 1 -type f -name "${VULN_REPORT_PATTERN}"
) | sort | cut -c3- > "${FILE_LIST}"

tar -czvf "${SECURITY_REPORTS_BUNDLE}" --files-from="${FILE_LIST}"

BACKUP_TAG="${AUTHORITATIVE_TAG}-bak"
echo "Reports bundle ready! Creating a backup tag (${BACKUP_TAG}) ..."
(
    set -x
    exec docker tag "${AUTHORITATIVE_TAG}" "${BACKUP_TAG}"
) || exit ${?}

DF="Dockerfile.with-reports.${GITHUB_RUN_NUMBER}"
cat <<EOF > "${DF}"
FROM "${AUTHORITATIVE_TAG}"
COPY --chown=root:root --chmod=0444 "${SECURITY_REPORTS_BUNDLE}" "/${SECURITY_REPORTS_BUNDLE}"
EOF

# This time we add all the tags up front, since this will no longer be
# scanned
echo "Computing extra tags ..."
EXTRA_TAGS=()
for BUILD in "${BUILDS[@]}" ; do
    [ "${AUTHORITATIVE_TAG}" == "${BUILD}" ] || EXTRA_TAGS+=( --tag "${BUILD}" )
done

# No build args needed here b/c we don't need'em
(
    set -x
    exec docker build --file "${DF}" --tag "${AUTHORITATIVE_TAG}" "${EXTRA_TAGS[@]}" .
) || exit ${?}

echo "TAGS_ADDED='true'" | to_env
echo "TAGS_ADDED=true" | to_github_env
