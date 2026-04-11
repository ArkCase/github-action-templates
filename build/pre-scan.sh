#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

SCAN_ID="$( ( dd if=/dev/urandom bs=1 count=8 status=none | od -t x8 | head -1 | awk '{print $2 }' ) 2>&1)" || fail "Failed to generate the unique ID for the scanner volume (rc=${?}): ${SCAN_ID}"
to_env SCAN_ID

to_env SCAN_VOL="security-scan-${SCAN_ID}"
doing "Creating the Docker volume for the scan data"
docker volume create "${SCAN_VOL}"

#
# The base place where scan data will be stored
#
to_env SCAN_TGT_DIR="${GITHUB_WORKSPACE}/${SCAN_VOL}"

# Always clean ALL OF IT out, and re-create!
rm -rf "${SCAN_TGT_DIR}"
mkdir -p "${SCAN_TGT_DIR}"

#
# Now define all of the other variables!
#

# TODO: account for the branch name!
to_env COMP_REPORT_BASE="compliance${ARTIFACT_IDENTIFIER}"
to_env COMP_REPORT_PATH="${SCAN_TGT_DIR}/${COMP_REPORT_BASE}"
to_env COMP_REPORT_PATTERN="${COMP_REPORT_PATH}.*"
to_env COMP_REPORT_XML_SOURCE="${COMP_REPORT_PATH}.xml"
to_env COMP_REPORT_HDF_SOURCE="${COMP_REPORT_PATH}.hdf"
to_env COMP_REPORT_HTML_SOURCE="${COMP_REPORT_PATH}.html"
to_env COMP_REPORT_SARIF_SOURCE="${COMP_REPORT_PATH}.sarif"

# TODO: account for the branch name!
to_env VULN_REPORT_BASE="vulnerabilities${ARTIFACT_IDENTIFIER}"
to_env VULN_REPORT_PATH="${SCAN_TGT_DIR}/${VULN_REPORT_BASE}"
to_env VULN_REPORT_PATTERN="${VULN_REPORT_PATH}.*"
to_env VULN_REPORT_JSON_SOURCE="${VULN_REPORT_PATH}.json"
to_env VULN_REPORT_HTML_SOURCE="${VULN_REPORT_PATH}.html"
to_env VULN_REPORT_SARIF_SOURCE="${VULN_REPORT_PATH}.sarif"
to_env VULN_REPORT_SBOM_SOURCE="${VULN_REPORT_PATH}.cdx"
