#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

SCAN_TYPE="${1:-}"

[ -n "${SCAN_TYPE}" ] || fail "Must provide a scan type"

SCAN_OVERRIDE="OVERRIDE_${SCAN_TYPE^^}_SCAN"
if is_envvar "${SCAN_OVERRIDE}" && [ -v "${SCAN_OVERRIDE}" ] ; then
	VAL="${!SCAN_OVERRIDE}"
	case "${VAL,,}" in
		true ) quit "The ${SCAN_OVERRIDE} variable is set to 'true' - skipping the ${SCAN_TYPE^^} scan!"
	esac
fi

echo "Launching the ${SCAN_TYPE^^} Scan for ${AUTHORITATIVE_TAG}..."
TMP_SCAN_DIR="${SCAN_DIR}/${SCAN_TYPE}"
mkdir -p "${TMP_SCAN_DIR}"

cleanup()
{
	rm -rf "${TMP_SCAN_DIR}" &>/dev/null
}
trap cleanup EXIT

date -Ins -u > "${TMP_SCAN_DIR}/.started"
DOCKER_SOCKET="/var/run/docker.sock"

CONTAINER_NAME_SUFFIX="${IMAGE_URI//\//-}"
[ -n "${ARTIFACT_IDENTIFIER}" ] && CONTAINER_NAME_SUFFIX+="-${ARTIFACT_IDENTIFIER}"

# Compute the scanner image, and use a default if needed
if [ -n "${SCANNER_IMAGE:-}" ] ; then
	# This allows for the use of ${VAR} in the scanner image specification
	VARS=( '$PUBLIC_REGISTRY' '$PRIVATE_REGISTRY' '$REVISION_PREFIX' )
	NEW_SCANNER_IMAGE="$(echo -n "${SCANNER_IMAGE}" | envsubst "${VARS[@]}")"
	[ -n "${NEW_SCANNER_IMAGE}" ] || fail "The scanner image spec [${SCANNER_IMAGE}] resolved to an empty string!"
	SCANNER_IMAGE="${NEW_SCANNER_IMAGE}"
else
	SCANNER_IMAGE="${PRIVATE_REGISTRY}/arkcase/security-scanner:latest"
fi

CMD=(
	docker run
		--rm
		--name "${SCAN_TYPE}-${CONTAINER_NAME_SUFFIX}"
		--env RESULTS_NAME="${SCAN_TYPE}${ARTIFACT_IDENTIFIER}"
)

[ -n "${DOCKER_HOST:-}" ] \
	&& CMD+=( --env DOCKER_HOST="${DOCKER_HOST}" ) \
	|| CMD+=( --volume "${DOCKER_SOCKET}:${DOCKER_SOCKET}" )

CMD+=(
	--volume "${TMP_SCAN_DIR}:/results"
	"${SCANNER_IMAGE}"
	"${SCAN_TYPE}" "${AUTHORITATIVE_TAG}"
)

# Run the command!
EXIT_CODE=0
echo "Launching: ${CMD[@]@Q}"
"${CMD[@]}" || EXIT_CODE=${?}

#
# Regardless of what happened, fix the permissions!
#
sudo chown --reference="${GITHUB_WORKSPACE}" -R "${TMP_SCAN_DIR}" || true
sudo chmod -R u=rwX,go=rX "${TMP_SCAN_DIR}" || true

#
# Now copy the stuff over
#
( cd "${TMP_SCAN_DIR}" && tar -cf - . ) | tar -C "${SCAN_DIR}" -xvf - || true

case "${EXIT_CODE}" in
	0 | 2 ) exit 0 ;;
	* ) exit ${EXIT_CODE} ;;
esac
