{{- with secret "gcp/static-account/vault-kms-unsealer/key" }}
{{- .Data.private_key_data | base64Decode }}
{{- end }}
