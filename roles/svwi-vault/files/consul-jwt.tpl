{{- with secret "identity/oidc/token/consul-auto-config-vault" }}
{{- .Data.token }}
{{- end }}