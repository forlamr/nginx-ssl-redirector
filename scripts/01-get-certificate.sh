#!/bin/bash

if [ -d "/certs" ]; then
    cp -v /certs/*.crt /etc/ssl/certs/nginx-cert.crt
    cp -v /certs/*.key /etc/ssl/private/nginx-cert.key
    echo "Certificates copied to /etc/ssl/certs and /etc/ssl/private."
else
    apt update && apt install -y jq
    if [ -z "$TOKEN" ]; then
        TOKEN_RESULT=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net&client_id=$UMI_CLIENT_ID")
        TOKEN=$(echo $TOKEN_RESULT | jq -r '.access_token')
    fi
    VAULT_RESULT=$(curl -s -H "Authorization: Bearer $TOKEN" "${KV_SECRET_URL}?api-version=7.2")
    SECRET=$(echo $VAULT_RESULT | jq -r '.value')
    echo $SECRET | base64 -d > /tmp/certificate.pfx
    openssl pkcs12 -in /tmp/certificate.pfx -nokeys -clcerts -passin pass: -out /etc/ssl/certs/nginx-cert.crt
    openssl pkcs12 -in /tmp/certificate.pfx -nocerts -nodes -passin pass: -out /etc/ssl/private/nginx-cert.key
    #cat /etc/ssl/certs/nginx-cert.crt
    #cat /etc/ssl/private/nginx-cert.key
    rm -f /tmp/certificate.pfx
    echo "Certificates retrieved from Azure Key Vault and saved to /etc/ssl/certs and /etc/ssl/private."
fi