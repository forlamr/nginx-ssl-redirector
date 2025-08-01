param(
    [string]$KeyVaultSecretUrl = "https://kv-lgcertificates.vault.azure.net/secrets/lgtest-eu-wildcard2cbd9cbc-05e5-4efe-a81e-695a183ff1ea/a0b6cbb2632243f59d6497311839dbd1"
)

$pwd_slashes = $pwd -replace '\\', '/'
$token_result = az account get-access-token --resource https://vault.azure.net | ConvertFrom-Json
$token = $token_result.accessToken
docker run --rm `
  --mount "type=bind,source=$pwd_slashes/scripts,target=/docker-entrypoint.d/init-scripts" `
  --mount "type=bind,source=$pwd_slashes/templates,target=/etc/nginx/templates" `
  -e TOKEN=$token `
  -e KV_SECRET_URL=$KeyVaultSecretUrl `
  -e NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx `
  -e IOTHUB_HOSTNAME=testgewissiotcipher.azure-devices.net `
  -p 8883:8883 `
  -p 4080:80 `
  -p 4443:443 `
  nginx:latest

#--mount "type=bind,source=$pwd_slashes/secrets,target=/certs" `
