# quay

<!-- markdownlint-disable MD013 -->
![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.9](https://img.shields.io/badge/AppVersion-3.9-informational?style=flat-square)
<!-- markdownlint-enable MD013 -->

<!-- markdownlint-disable MD013 -->
Red Hat Quay Registry Resources
<!-- markdownlint-enable MD013 -->

This chart is used to serve as the template for Validated Patterns Charts

## Notable changes

### 0.2.0

- Standalone Multicloud Object Gateway is the default object storage
  backend (`objectStorage.mode=mcg`). Set `objectStorage.mode=odf` to use
  an existing OpenShift Data Foundation StorageCluster instead.
- An OpenShift console link points at the Quay route and embeds the Quay icon.
- Users, organizations, and repositories are applied by a Job and CronJob
  using the `infra.quay_configuration` Ansible collection. Passwords are
  projected with an ExternalSecret.
- `quay.setup` and `quay_config` moved to `quayConfig`.

**Homepage:** <https://github.com/validatedpatterns/quay-chart>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Zero Trust Validated Patterns Team | <ztvp-arch-group@redhat.com> |  |

<!-- markdownlint-disable MD013 MD034 MD060 -->
## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| configJob.activeDeadlineSeconds | int | `1800` | Job activeDeadlineSeconds for the bootstrap Job and CronJob pods. |
| configJob.backoffLimit | int | `5` |  |
| configJob.collectionVersion | string | `"2.8.1"` | infra.quay_configuration version passed to ansible-galaxy. |
| configJob.enabled | bool | `true` | Run the bootstrap Job and the reconciling CronJob. |
| configJob.failedJobsHistoryLimit | int | `1` |  |
| configJob.image | string | `"quay.io/hybridcloudpatterns/imperative-container:v1"` | Image with ansible-core, ansible-galaxy, oc, and cURL. |
| configJob.imagePullPolicy | string | `"Always"` |  |
| configJob.installCollection | bool | `true` | Install infra.quay_configuration into an emptyDir before the playbook. Set false when configJob.image already contains the collection. |
| configJob.resources.limits.cpu | string | `"500m"` |  |
| configJob.resources.limits.memory | string | `"512Mi"` |  |
| configJob.resources.requests.cpu | string | `"50m"` |  |
| configJob.resources.requests.memory | string | `"256Mi"` |  |
| configJob.schedule | string | `"*/30 * * * *"` | Cron schedule for re-applying Quay configuration. |
| configJob.successfulJobsHistoryLimit | int | `1` |  |
| configJob.validateCerts | bool | `false` | Verify the Quay route TLS certificate. In-cluster routes often use a private CA, so the default is false. |
| consoleLink.enabled | bool | `true` | Create an ApplicationMenu ConsoleLink for the Quay route. |
| consoleLink.href | string | `""` | Override the computed route URL. Empty builds the managed route from quay.name, quay.namespace, and global.clusterDomain. |
| consoleLink.name | string | `"quay"` | ConsoleLink metadata.name. |
| consoleLink.section | string | `"Red Hat applications"` | Application menu section. |
| consoleLink.text | string | `"Red Hat Quay"` | Menu text. |
| global.clusterDomain | string | `"example.com"` | OpenShift cluster base domain. Used in the console link when consoleLink.href is empty. The host is apps. plus this domain. |
| job.image | string | `"quay.io/validatedpatterns/imperative-container:v1"` | Image for the S3 credentials Job. Uses the OpenShift cli ImageStream, which tracks the cluster version. Override when the internal registry is unavailable, for example ose-cli-rhel9:v4.20. |
| job.resources.limits.cpu | string | `"500m"` |  |
| job.resources.limits.memory | string | `"512Mi"` |  |
| job.resources.requests.cpu | string | `"50m"` |  |
| job.resources.requests.memory | string | `"128Mi"` |  |
| objectStorage.mcg.backingStore.name | string | `"noobaa-default-backing-store"` | BackingStore that holds the gateway's persistent volumes. |
| objectStorage.mcg.bucketClass.name | string | `"noobaa-default-bucket-class"` | BucketClass used by the default NooBaa storage class. |
| objectStorage.mcg.bucketClass.placement.tiers[0].backingStores[0] | string | `"noobaa-default-backing-store"` |  |
| objectStorage.mcg.dbSize | string | `"50Gi"` | Size of the NooBaa PostgreSQL volume. |
| objectStorage.mcg.namespace | string | `"openshift-storage"` | Namespace of the NooBaa system. Must match the ODF operator namespace. |
| objectStorage.mcg.pvPool.numVolumes | int | `1` | Number of persistent volumes in the backing store pool. |
| objectStorage.mcg.pvPool.resources.limits.cpu | string | `"1"` |  |
| objectStorage.mcg.pvPool.resources.limits.memory | string | `"4Gi"` |  |
| objectStorage.mcg.pvPool.resources.requests.cpu | string | `"800m"` |  |
| objectStorage.mcg.pvPool.resources.requests.memory | string | `"800Mi"` |  |
| objectStorage.mcg.pvPool.resources.requests.storage | string | `"50Gi"` |  |
| objectStorage.mcg.system.name | string | `"noobaa"` | Name of the NooBaa custom resource. |
| objectStorage.mode | string | `"mcg"` | mcg deploys the standalone Multicloud Object Gateway. odf consumes an existing OpenShift Data Foundation StorageCluster. |
| objectStorage.objectBucketClaim.bucketName | string | `"quay-datastore"` | Prefix passed to generateBucketName. |
| objectStorage.objectBucketClaim.name | string | `"quay-bucket"` | ObjectBucketClaim name. The bound ConfigMap and Secret use this name. |
| objectStorage.objectBucketClaim.storageClass | string | `"openshift-storage.noobaa.io"` | StorageClass for the claim. Override for Ceph RGW, for example ocs-storagecluster-ceph-rgw. |
| quay.configBundleSecret.deploy | bool | `true` |  |
| quay.configBundleSecret.name | string | `"quay-init-config-bundle-secret"` | Template secret. The S3 job copies it and fills storage placeholders. |
| quay.configBundleSecret.s3Name | string | `"quay-config-with-s3"` | Secret QuayRegistry reads after the S3 job fills credentials. |
| quay.name | string | `"quay-registry"` | Name of the QuayRegistry resource. The managed route is this name with -quay appended. |
| quay.namespace | string | `"quay-enterprise"` | Namespace for the Quay registry and its configuration jobs. |
| quay.storage.clairpostgres.size | string | `"50Gi"` | Persistent volume size for the Clair PostgreSQL database. |
| quay.storage.postgres.size | string | `"50Gi"` | Persistent volume size for the Quay PostgreSQL database. |
| quayConfig.credentials.key | string | `"secret/data/hub/quay-users"` | Vault (or other backend) path extracted into quay-config-credentials. |
| quayConfig.organizations | list | `[]` |  |
| quayConfig.repositories | list | `[]` |  |
| quayConfig.users[0].email | string | `"quayadmin@example.com"` |  |
| quayConfig.users[0].initialize | bool | `true` |  |
| quayConfig.users[0].name | string | `"quayadmin"` |  |
| quayConfig.users[0].passwordProperty | string | `"quay-admin-password"` | Property on credentials.key projected into the credentials Secret. |
| quayConfig.users[0].superuser | bool | `true` |  |
| secretStore.kind | string | `"ClusterSecretStore"` | Kind of secretStore.name. |
| secretStore.name | string | `"vault-backend"` | SecretStore or ClusterSecretStore that holds Quay user passwords. |
<!-- markdownlint-enable MD013 MD034 MD060 -->

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
