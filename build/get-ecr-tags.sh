#!/bin/bash

set -euo pipefail

ECR="${1}"
QUERY="${2}"
JQ_FIND_IMAGE_TAGS='.imageDetails[] | select(has("imageTags")) | .imageTags[]'

exec aws "${ECR}" describe-images --repository-name "${QUERY}" | jq -r "${JQ_FIND_IMAGE_TAGS}"
