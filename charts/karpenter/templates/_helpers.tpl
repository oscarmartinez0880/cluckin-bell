{{/*
Expand the name of the chart.
*/}}
{{- define "karpenter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "karpenter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "karpenter.labels" -}}
helm.sh/chart: {{ include "karpenter.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
