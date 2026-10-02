#!/bin/bash
# Wait for the Quay route, then apply the configuration playbook.
set -euo pipefail

quay_namespace="${QUAY_NAMESPACE:?QUAY_NAMESPACE is required}"
quay_route="${QUAY_ROUTE:?QUAY_ROUTE is required}"
install_collection="${INSTALL_COLLECTION:?INSTALL_COLLECTION is required}"
validate_certs="${VALIDATE_CERTS:?VALIDATE_CERTS is required}"
home_dir="${HOME_DIR:-/pattern-home}"

route_host=""
echo "Waiting for route ${quay_route} in ${quay_namespace}..."
for _ in $(seq 1 60); do
	route_host="$(
		oc get route "${quay_route}" -n "${quay_namespace}" \
			-o jsonpath='{.status.ingress[0].host}' 2>/dev/null || true
	)"
	if [[ -n "${route_host}" ]]; then
		break
	fi
	sleep 10
done

if [[ -z "${route_host}" ]]; then
	echo "ERROR: route ${quay_route} has no admitted host" >&2
	oc describe route "${quay_route}" -n "${quay_namespace}" || true
	exit 1
fi

quay_host="https://${route_host}"
echo "Quay host is ${quay_host}"

ready=""
for _ in $(seq 1 60); do
	if curl -kfsS --max-time 5 "${quay_host}/health/instance" >/dev/null; then
		ready="yes"
		break
	fi
	sleep 10
done

if [[ -z "${ready}" ]]; then
	echo "ERROR: Quay health endpoint did not become ready" >&2
	exit 1
fi

if [[ "${install_collection}" == "true" ]]; then
	collections_path="${COLLECTIONS_PATH:?COLLECTIONS_PATH is required}"
	export ANSIBLE_COLLECTIONS_PATH="${collections_path}"
fi

export HOME="${home_dir}"
# The imperative container sets ANSIBLE_REMOTE_TMP to ${HOME}/.ansible/tmp.
# Recreate that directory on the writable home mount before the playbook runs.
export ANSIBLE_REMOTE_TMP="${home_dir}/.ansible/tmp"
export ANSIBLE_LOCAL_TEMP="${home_dir}/.ansible/tmp"
mkdir -p "${ANSIBLE_REMOTE_TMP}"

ansible-playbook /quay-config/playbook.yml \
	-e "quay_host=${quay_host}" \
	-e "validate_certs=${validate_certs}"
