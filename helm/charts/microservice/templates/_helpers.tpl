{{/*
Expand the name of the chart.
*/}}
{{- define "microservice.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "microservice.fullname" -}}
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
{{- define "microservice.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "microservice.labels" -}}
helm.sh/chart: {{ include "microservice.chart" . }}
{{ include "microservice.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "microservice.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "microservice.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "microservice.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create image reference
*/}}
{{- define "microservice.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.microservice.image.registry -}}
{{- $repository := .Values.microservice.image.repository -}}
{{- $tag := .Values.microservice.image.tag | default .Chart.AppVersion -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Database connection URL
*/}}
{{- define "microservice.databaseURL" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "postgresql://%s:%s@%s-postgresql:5432/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password .Release.Name .Values.postgresql.auth.database -}}
{{- else if .Values.externalDatabase.enabled -}}
{{- printf "%s://%s:%s@%s:%d/%s" .Values.externalDatabase.type .Values.externalDatabase.username .Values.externalDatabase.password .Values.externalDatabase.host (.Values.externalDatabase.port | int) .Values.externalDatabase.database -}}
{{- end -}}
{{- end }}

{{/*
Redis connection URL
*/}}
{{- define "microservice.redisURL" -}}
{{- if .Values.redis.enabled -}}
{{- if .Values.redis.auth.enabled -}}
{{- printf "redis://:%s@%s-redis-master:6379" .Values.redis.auth.password .Release.Name -}}
{{- else -}}
{{- printf "redis://%s-redis-master:6379" .Release.Name -}}
{{- end -}}
{{- else if .Values.externalCache.enabled -}}
{{- if .Values.externalCache.password -}}
{{- printf "redis://:%s@%s:%d" .Values.externalCache.password .Values.externalCache.host (.Values.externalCache.port | int) -}}
{{- else -}}
{{- printf "redis://%s:%d" .Values.externalCache.host (.Values.externalCache.port | int) -}}
{{- end -}}
{{- end -}}
{{- end }}
