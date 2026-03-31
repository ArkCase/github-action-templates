#!/bin/bash

set -euo pipefail

if [ -z "${GITHUB_ACTION_PATH:-}" ] ; then
	THIS_SCRIPT="$(readlink -f "${BASH_ARGV0:${BASH_SOURCE:-${0}}}")"
	export GITHUB_ACTION_PATH="$(dirname "${THIS_SCRIPT}")"
fi

# If there's no work directory, put it in the same directory as the action
[ -n "${WORK_DIR:-}" ] || export WORK_DIR="${GITHUB_ACTION_PATH}"

# If there's no pre-defined environment file, put it in the work directory
[ -n "${ENV_FILE:-}" ] || export ENV_FILE="${WORK_DIR}/.env"

. "${ENV_FILE}"

# All images have private repositories
echo "Creating the private repository for ${IMAGE_URI}..."
aws ecr create-repository \
	--repository-name "${IMAGE_URI}" \
	--region "${AWS_REGION}" \
	--image-tag-mutability MUTABLE \
	--image-scanning-configuration scanOnPush=true \
	--encryption-configuration encryptionType="AES256" || true

"${PUSH_TO_PUBLIC}" || exit 0

IMAGE_REAL_URI="${IMAGE_URI}"
[[ "${IMAGE_URI}" =~ ^arkcase/(.*)$ ]] && IMAGE_REAL_URI="${BASH_REMATCH[1]}"

echo "Creating the public repository for ${IMAGE_URI} (as ${IMAGE_REAL_URI})..."
aws ecr-public create-repository \
	--repository-name "${IMAGE_REAL_URI}" \
	--region "${ECR_AWS_REGION}" || true

exit 0
