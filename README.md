# IoT Hub Redirector

A containerized nginx-based SSL proxy solution for Azure IoT Hub that provides secure certificate management and traffic redirection.

## Overview

This project creates an Azure Container Instance running nginx that acts as an SSL proxy to Azure IoT Hub. It automatically retrieves SSL certificates from Azure Key Vault using managed identity authentication and provides secure traffic forwarding on ports 443 and 8883.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   IoT Devices   │──> │  Container       │───>│   Azure IoT     │
│                 │    │  Instance        │    │   Hub           │
│                 │    │  (nginx proxy)   │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  Azure Key       │
                       │  Vault           │
                       │  (Certificates)  │
                       └──────────────────┘
```

## Components

### Azure Resources

- **Container Instance**: Runs nginx with SSL proxy configuration
- **Storage Account**: Hosts configuration files and scripts via Azure Files
- **User Assigned Managed Identity**: Provides secure access to Key Vault
- **Log Analytics Workspace**: Collects container logs and diagnostics

### Files Structure

```
├── create-containerinstance.ps1    # Main deployment script
├── run-docker-locally.ps1          # Local development script
├── scripts/
│   └── 01-get-certificate.sh       # Certificate retrieval script
└── templates/
    └── nginx.conf.template         # Nginx configuration template
```

## Features

- 🔐 **Automatic Certificate Management**: Retrieves SSL certificates from Azure Key Vault
- 🌐 **SSL Proxy**: Secure forwarding to Azure IoT Hub on port 8883
- 🔄 **Auto-restart**: Container restarts automatically on failure
- 📊 **Monitoring**: Integrated with Azure Log Analytics
- 🏗️ **Infrastructure as Code**: Automated Azure resource deployment
- 🐳 **Containerized**: Easy deployment and scaling

## Prerequisites

- Azure CLI installed and configured
- PowerShell 7+ (pwsh)
- Azure subscription with appropriate permissions
- Azure Key Vault with SSL certificate stored as base64-encoded PFX
- Log Analytics workspace

## Quick Start

### 1. Certificate Preparation

Store your SSL certificate (pfx) in Azure Key Vault and gather the secret URL.

### 2. Deploy Infrastructure

Run the deployment script with required parameters:

```powershell
.\create-containerinstance.ps1 `
    -ResourceGroup "rg-iot-redirector" `
    -ContainerInstanceName "iot-proxy" `
    -StorageAccountName "stiotproxy001" `
    -UmiName "umi-iot-proxy" `
    -LogAnalyticsWorkspaceName "law-iot-proxy" `
    -LogAnalyticsWorkspaceResourceGroup "rg-monitoring" `
    -DnsLabel "iot-proxy-prod" `
    -KeyVaultSecretUrl "https://your-keyvault.vault.azure.net/secrets/ssl-cert" `
    -IothubHostname "your-iothub.azure-devices.net" `
    -Location "ItalyNorth"
```

### 3. Verify Deployment

After successful deployment, the script will output:

```
✅ Deployment completed successfully!
Resources created:
  📦 Storage Account: stiotproxy001
  🔐 Managed Identity: umi-iot-proxy (Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  🐳 Container Instance: iot-proxy
  🌐 FQDN: iot-proxy-prod.italynorth.azurecontainer.io
  🌍 Public IP: 20.123.45.67
  📊 Diagnostics: Connected to Log Analytics workspace 'law-iot-proxy'
```

## Configuration

### Environment Variables

The container uses the following environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `KV_SECRET_URL` | Azure Key Vault secret URL | `https://kv.vault.azure.net/secrets/cert` |
| `NGINX_ENVSUBST_OUTPUT_DIR` | Nginx config output directory | `/etc/nginx` |
| `IOTHUB_HOSTNAME` | Target IoT Hub hostname | `myiothub.azure-devices.net` |
| `UMI_CLIENT_ID` | Managed Identity client ID | Auto-populated |

### Nginx Configuration

The nginx configuration template (`templates/nginx.conf.template`) supports:

- SSL termination on ports 443 and 8883
- Health check endpoint at `/health`
- Upstream proxy to Azure IoT Hub
- Configurable SSL protocols (TLS 1.2/1.3)

## Local Development

For local testing, use the provided Docker script:

```powershell
.\run-docker-locally.ps1
```

This script:

- Builds a local nginx container
- Mounts local certificates from `secrets/` folder
- Exposes ports for testing

## Security Considerations

- **Managed Identity**: Uses Azure Managed Identity for Key Vault access (no secrets in code)
- **Certificate Rotation**: Automatically retrieves fresh certificates on container restart
- **Network Security**: Consider using Azure Virtual Network for production deployments
- **Key Vault Access**: Ensure proper RBAC permissions for the managed identity

## Monitoring and Troubleshooting

### Log Analytics Queries

Use these KQL queries to monitor the container:

```kql
// Container logs
ContainerInstanceLog_CL
| where ContainerGroup_s == "your-container-name"
| order by TimeGenerated desc
```

### Common Issues

1. **Certificate not found**: Verify Key Vault permissions and secret URL
2. **Connection refused**: Check IoT Hub hostname and network connectivity
3. **SSL errors**: Ensure certificate matches the expected domain

## Cost Optimization

- Use **Standard_LRS** storage for non-critical environments
- Monitor container CPU/memory usage and adjust resources accordingly

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally using the development script
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changelog

### v1.0.0

- Initial release with basic SSL proxy functionality
- Azure Key Vault integration
- Automated certificate retrieval
- Log Analytics integration
- PowerShell deployment automation
