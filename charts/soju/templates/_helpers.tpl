{{/*
Expand the name of the chart.
*/}}
{{- define "soju.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "soju.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "soju.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "soju.labels" -}}
helm.sh/chart: {{ include "soju.chart" . }}
{{ include "soju.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "soju.selectorLabels" -}}
app.kubernetes.io/name: {{ include "soju.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Database DSN for soju.conf
Returns the full "db <driver> <source>" line content
*/}}
{{- define "soju.databaseDSN" -}}
{{- if eq .Values.database.driver "sqlite3" -}}
sqlite3 {{ .Values.database.sqlite.path }}
{{- else if eq .Values.database.driver "postgres" -}}
postgres "host={{ include "soju.postgresql.host" . }} port={{ .Values.database.postgres.port }} dbname={{ .Values.database.postgres.database }} user={{ .Values.database.postgres.user }} password=POSTGRES_PASSWORD sslmode={{ .Values.database.postgres.sslmode }}"
{{- end -}}
{{- end -}}

{{/*
PostgreSQL host helper
Priority: external host > bundled StatefulSet
*/}}
{{- define "soju.postgresql.host" -}}
{{- if .Values.database.postgres.host -}}
{{ .Values.database.postgres.host }}
{{- else -}}
{{ include "soju.fullname" . }}-postgresql
{{- end -}}
{{- end -}}

{{/*
PostgreSQL secret name helper
*/}}
{{- define "soju.postgresql.secretName" -}}
{{- if .Values.database.postgres.existingSecret -}}
{{ .Values.database.postgres.existingSecret }}
{{- else -}}
{{ include "soju.fullname" . }}-postgresql
{{- end -}}
{{- end -}}

{{/*
Admin secret name helper
*/}}
{{- define "soju.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}
{{ .Values.admin.existingSecret }}
{{- else -}}
{{ include "soju.fullname" . }}-admin
{{- end -}}
{{- end -}}

{{/*
TLS secret name helper
Priority: certificate > tls.existingSecret > generated name
*/}}
{{- define "soju.tlsSecretName" -}}
{{- if .Values.certificate.enabled -}}
{{ .Values.certificate.secretName }}
{{- else if .Values.tls.existingSecret -}}
{{ .Values.tls.existingSecret }}
{{- else -}}
{{ include "soju.fullname" . }}-tls
{{- end -}}
{{- end -}}

{{/*
Whether TLS is available (certificate or existing secret)
*/}}
{{- define "soju.tlsEnabled" -}}
{{- if or .Values.certificate.enabled .Values.tls.existingSecret -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Primary probe port (first available listener)
*/}}
{{- define "soju.probePort" -}}
{{- if .Values.listeners.websocket -}}
websocket
{{- else if .Values.listeners.ircs -}}
ircs
{{- else -}}
irc
{{- end -}}
{{- end -}}
