#!/bin/bash
# Fill the Quay config template from a bound ObjectBucketClaim.
set -euo pipefail

quay_namespace="${QUAY_NAMESPACE:?QUAY_NAMESPACE is required}"
obc_name="${OBC_NAME:?OBC_NAME is required}"
config_secret="${CONFIG_SECRET:?CONFIG_SECRET is required}"
output_secret="${OUTPUT_SECRET:?OUTPUT_SECRET is required}"

echo "Setting up S3 credentials for Quay from ObjectBucketClaim ${obc_name}..."

oc get objectbucketclaim "${obc_name}" -n "${quay_namespace}"

echo "Waiting for ObjectBucketClaim ${obc_name} to be Bound (timeout: 10 minutes)..."
if ! oc wait --for=jsonpath='{.status.phase}'=Bound \
	"objectbucketclaim/${obc_name}" -n "${quay_namespace}" --timeout=600s; then
	echo "ERROR: ObjectBucketClaim failed to reach Bound state within timeout" >&2
	oc describe objectbucketclaim "${obc_name}" -n "${quay_namespace}"
	exit 1
fi

access_key="$(
	oc get secret "${obc_name}" -n "${quay_namespace}" \
		-o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d
)"
secret_key="$(
	oc get secret "${obc_name}" -n "${quay_namespace}" \
		-o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d
)"
bucket_name="$(
	oc get configmap "${obc_name}" -n "${quay_namespace}" \
		-o jsonpath='{.data.BUCKET_NAME}'
)"
bucket_host="$(
	oc get configmap "${obc_name}" -n "${quay_namespace}" \
		-o jsonpath='{.data.BUCKET_HOST}'
)"
bucket_port="$(
	oc get configmap "${obc_name}" -n "${quay_namespace}" \
		-o jsonpath='{.data.BUCKET_PORT}'
)"

if [[ -z "${bucket_port}" ]]; then
	bucket_port="443"
fi

if [[ "${bucket_port}" == "443" ]]; then
	is_secure="true"
else
	is_secure="false"
fi

if [[ -z "${bucket_host}" || -z "${bucket_name}" || -z "${access_key}" || -z "${secret_key}" ]]; then
	echo "ERROR: ObjectBucketClaim ${obc_name} is missing endpoint or credentials" >&2
	exit 1
fi

echo "Retrieved S3 credentials successfully"
echo "Bucket: ${bucket_name}"
echo "Endpoint: ${bucket_host}:${bucket_port}"

oc get secret "${config_secret}" -n "${quay_namespace}" \
	-o jsonpath='{.data.config\.yaml}' | base64 -d >/tmp/config.yaml

sed -i \
	-e "s|PLACEHOLDER_ACCESS_KEY|${access_key}|g" \
	-e "s|PLACEHOLDER_SECRET_KEY|${secret_key}|g" \
	-e "s|PLACEHOLDER_BUCKET_NAME|${bucket_name}|g" \
	-e "s|PLACEHOLDER_BUCKET_HOST|${bucket_host}|g" \
	-e "s|PLACEHOLDER_BUCKET_PORT|${bucket_port}|g" \
	-e "s|PLACEHOLDER_IS_SECURE|${is_secure}|g" \
	/tmp/config.yaml

echo "Creating ${output_secret} with credentials from the ObjectBucketClaim..."
oc create secret generic "${output_secret}" \
	--from-file=config.yaml=/tmp/config.yaml \
	-n "${quay_namespace}" \
	--dry-run=client -o yaml | oc apply -f -

echo "Quay S3 credentials setup completed successfully"
