#!/bin/bash
# Install infra.quay_configuration onto the shared work volume.
set -euo pipefail

collections_path="${COLLECTIONS_PATH:?COLLECTIONS_PATH is required}"
requirements="/quay-config/requirements.yml"

if [[ ! -f "${requirements}" ]]; then
	echo "ERROR: ${requirements} is missing" >&2
	exit 1
fi

mkdir -p "${collections_path}"
ansible-galaxy collection install -r "${requirements}" -p "${collections_path}"
