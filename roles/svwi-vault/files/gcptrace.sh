#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/hashicorp/vault/log.out 2>&1

FILE=$(/usr/bin/vault login -no-print token=@/run/vault-vault/vault.token && /usr/bin/vault read -format=json gcp/static-account/vault-kms-unsealer/key ttl=1h)

echo $FILE

PRIVKEY=$(echo $FILE | jq -j ".data.private_key_data")

echo $PRIVKEY

DECODE=$(echo $PRIVKEY | base64 --decode)

echo $DECODE

echo $DECODE > /hashicorp/vault/gcpckms.json

cat /hashicorp/vault/gcpckms.json