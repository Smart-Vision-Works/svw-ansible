{{- with secret "/gcp/roleset/vault-snapshot/token" }}
{{- .Data.token | regexReplaceAll "\\.{3,}" "" }}
{{- end }}