#!/bin/bash

export VAULT_ADDR="https://vault1.svwi.us:8200"


echo "Please enter you Google Workspace email:"

read username
splitName=${username%@*}

vault login -no-print -method=ldap -path=google-ldap username=$splitName && vault read databases/creds/pipeline