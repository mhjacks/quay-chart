{{/*
Validate quayConfig.users, organizations, and repositories.
Renders nothing. Fails the release on invalid input.
*/}}
{{- define "quay.config.validate" -}}
{{- $inits := 0 -}}
{{- $supers := 0 -}}
{{- range .Values.quayConfig.users }}
{{- if not .name }}
{{- fail "each quayConfig.users entry needs a name" }}
{{- end }}
{{- if not .passwordProperty }}
{{- fail (printf "user %s needs passwordProperty" .name) }}
{{- end }}
{{- if .initialize }}
{{- $inits = add $inits 1 }}
{{- if not .superuser }}
{{- fail (printf "initialize user %s must be a superuser" .name) }}
{{- end }}
{{- end }}
{{- if .superuser }}
{{- $supers = add $supers 1 }}
{{- end }}
{{- end }}
{{- if ne (int $inits) 1 }}
{{- fail "quayConfig.users must include exactly one user with initialize: true" }}
{{- end }}
{{- if lt (int $supers) 1 }}
{{- fail "quayConfig.users must include at least one superuser" }}
{{- end }}
{{- range .Values.quayConfig.organizations }}
{{- if lt (len .name) 4 }}
{{- fail (printf "organization name %q must be at least 4 characters" .name) }}
{{- end }}
{{- end }}
{{- range .Values.quayConfig.repositories }}
{{- if not (contains "/" .name) }}
{{- fail (printf "repository name %q must be namespace/name" .name) }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "quay.pod.securityContext" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "quay.container.securityContext" -}}
allowPrivilegeEscalation: false
runAsNonRoot: true
readOnlyRootFilesystem: true
capabilities:
  drop:
    - ALL
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{/*
Managed Quay route name: <quay.name>-quay.
*/}}
{{- define "quay.routeName" -}}
{{- printf "%s-quay" .Values.quay.name -}}
{{- end -}}

{{/*
ConsoleLink href. consoleLink.href wins when set.
*/}}
{{- define "quay.console.href" -}}
{{- if .Values.consoleLink.href -}}
{{- .Values.consoleLink.href -}}
{{- else -}}
{{- printf "https://%s-%s.apps.%s" (include "quay.routeName" .) .Values.quay.namespace .Values.global.clusterDomain -}}
{{- end -}}
{{- end -}}

{{/*
Ansible playbook for infra.quay_configuration. Passwords stay in the
mounted Secret and are read with a file lookup.
*/}}
{{- define "quay.config.playbook" -}}
{{- include "quay.config.validate" . -}}
{{- $admin := dict -}}
{{- range .Values.quayConfig.users }}
{{- if .initialize }}
{{- $admin = . }}
{{- end }}
{{- end }}
---
- name: Configure Red Hat Quay
  hosts: localhost
  gather_facts: false
  vars:
    admin_username: {{ $admin.name | quote }}
    admin_password: "{{`{{ lookup('ansible.builtin.file', '/quay-config-secrets/`}}{{ $admin.passwordProperty }}{{`') }}`}}"
  tasks:
    - name: Create the first user when the registry is empty
      infra.quay_configuration.quay_first_user:
        username: {{ $admin.name | quote }}
        email: {{ $admin.email | quote }}
        password: "{{`{{ admin_password }}`}}"
        quay_host: "{{`{{ quay_host }}`}}"
        validate_certs: "{{`{{ validate_certs | bool }}`}}"
      register: first_user
      failed_when:
        - first_user.failed | default(false)
        - first_user.msg | default('') | string is not search('non-empty|already', ignorecase=True)
{{- range .Values.quayConfig.users }}
{{- if not .initialize }}
    - name: Ensure user {{ .name }} exists
      infra.quay_configuration.quay_user:
        username: {{ .name | quote }}
        email: {{ .email | quote }}
        password: "{{`{{ lookup('ansible.builtin.file', '/quay-config-secrets/`}}{{ .passwordProperty }}{{`') }}`}}"
        superuser: {{ .superuser }}
        state: present
        quay_host: "{{`{{ quay_host }}`}}"
        quay_username: "{{`{{ admin_username }}`}}"
        quay_password: "{{`{{ admin_password }}`}}"
        validate_certs: "{{`{{ validate_certs | bool }}`}}"
{{- end }}
{{- end }}
{{- range .Values.quayConfig.organizations }}
    - name: Ensure organization {{ .name }} exists
      infra.quay_configuration.quay_organization:
        name: {{ .name | quote }}
        email: {{ .email | quote }}
        state: present
        quay_host: "{{`{{ quay_host }}`}}"
        quay_username: "{{`{{ admin_username }}`}}"
        quay_password: "{{`{{ admin_password }}`}}"
        validate_certs: "{{`{{ validate_certs | bool }}`}}"
{{- end }}
{{- range .Values.quayConfig.repositories }}
    - name: Ensure repository {{ .name }} exists
      infra.quay_configuration.quay_repository:
        name: {{ .name | quote }}
        visibility: {{ .visibility | default "private" | quote }}
        state: present
        quay_host: "{{`{{ quay_host }}`}}"
        quay_username: "{{`{{ admin_username }}`}}"
        quay_password: "{{`{{ admin_password }}`}}"
        validate_certs: "{{`{{ validate_certs | bool }}`}}"
{{- end }}
{{- end -}}

{{/*
Pod spec shared by the Quay configuration Job and CronJob.
*/}}
{{- define "quay.config.podSpec" -}}
restartPolicy: Never
serviceAccountName: quay-config
automountServiceAccountToken: true
securityContext:
  {{- include "quay.pod.securityContext" . | nindent 2 }}
volumes:
  - name: tmp
    emptyDir: {}
  - name: work
    emptyDir: {}
  - name: quay-config
    configMap:
      name: quay-config
      defaultMode: 0555
  - name: quay-config-secrets
    secret:
      secretName: quay-config-credentials
{{- if .Values.configJob.installCollection }}
initContainers:
  - name: install-collection
    image: {{ .Values.configJob.image | quote }}
    imagePullPolicy: {{ .Values.configJob.imagePullPolicy }}
    securityContext:
      {{- include "quay.container.securityContext" . | nindent 6 }}
    resources:
      {{- toYaml .Values.configJob.resources | nindent 6 }}
    env:
      - name: COLLECTIONS_PATH
        value: /quay-work/collections
      - name: HOME
        value: /quay-work
    command:
      - /bin/bash
      - /quay-config/install.sh
    volumeMounts:
      - name: tmp
        mountPath: /tmp
      - name: work
        mountPath: /quay-work
      - name: quay-config
        mountPath: /quay-config
        readOnly: true
{{- end }}
containers:
  - name: configure-quay
    image: {{ .Values.configJob.image | quote }}
    imagePullPolicy: {{ .Values.configJob.imagePullPolicy }}
    securityContext:
      {{- include "quay.container.securityContext" . | nindent 6 }}
    resources:
      {{- toYaml .Values.configJob.resources | nindent 6 }}
    env:
      - name: QUAY_NAMESPACE
        value: {{ .Values.quay.namespace | quote }}
      - name: QUAY_ROUTE
        value: {{ include "quay.routeName" . | quote }}
      - name: INSTALL_COLLECTION
        value: {{ .Values.configJob.installCollection | quote }}
      - name: VALIDATE_CERTS
        value: {{ .Values.configJob.validateCerts | quote }}
      - name: COLLECTIONS_PATH
        value: /quay-work/collections
      - name: HOME_DIR
        value: /quay-work
    command:
      - /bin/bash
      - /quay-config/run.sh
    volumeMounts:
      - name: tmp
        mountPath: /tmp
      - name: work
        mountPath: /quay-work
      - name: quay-config
        mountPath: /quay-config
        readOnly: true
      - name: quay-config-secrets
        mountPath: /quay-config-secrets
        readOnly: true
{{- end -}}
