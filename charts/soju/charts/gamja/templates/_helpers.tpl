{{/*
Gamja fullname (scoped to parent release)
*/}}
{{- define "gamja.fullname" -}}
{{ .Release.Name }}-gamja
{{- end -}}

{{/*
Gamja labels
*/}}
{{- define "gamja.labels" -}}
app.kubernetes.io/name: gamja
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: web-client
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Gamja selector labels
*/}}
{{- define "gamja.selectorLabels" -}}
app.kubernetes.io/name: gamja
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: web-client
{{- end -}}
