# Deployment using Azure Container Apps

## Architecture

### Virtual Network (VNet)

- **VNet**: `vnet-{appname}-{locationshort}` with CIDR 10.0.0.0/16
- **Subnets**:
  - `default`: 10.0.0.0/24
  - `aca`: 10.0.1.0/24 (delegated to Microsoft.App/environments)
  - `AzureFirewallSubnet`: 10.0.2.0/26
  - `AzureFirewallManagementSubnet`: 10.0.2.64/26

### Log Analytics Workspace

- **Log Analytics Workspace**: `law-{appname}-{locationshort}`
  - Used for monitoring and diagnostics

### Storage Account & File Share

- **Storage Account**: `st{appname}{locationshort}{suffix}`
  - File Shares: `config`, `scripts` (used by the Container App)

### Managed Identity

- **User Assigned Managed Identity**: `umi-{appname}-{locationshort}`

### Container App Environment

- **Container App Environment**: `cae-{appname}-{locationshort}`
  - Type: Internal (BYOVNET - Bring Your Own Virtual Network)
  - Attached to the "aca" subnet (10.0.1.0/24)

### Container App

- **Container App**: `ca-nginx-forwarder-{appname}-{locationshort}`
  - Image: nginx:latest
  - Ingress: TCP on configurable ports (default 8883, 443)
  - Mounts AzureFile file share for configuration and scripts
  - Exposed externally via Azure Firewall

### Azure Firewall

- **Azure Firewall**: `afw-{appname}-{locationshort}`
  - Type: Basic
  - Public IP: `pip-fw-{appname}-{locationshort}`
  - Management Public IP: `pip-fwmgmt-{appname}-{locationshort}`
  - NAT Rules: Forward from public port 8883/443 → Container App

## File Structure

```
aca-iac/
├── main.bicep                           # Main template
├── README.md                            # This file
├── modules/
│   ├── vnet.bicep                       # Virtual Network and subnets
│   ├── firewall.bicep                   # Azure Firewall and public IPs
│   ├── firewall-policy.bicep            # Policy and NAT rules
│   ├── container-app-environment.bicep  # Container App Environment
│   ├── nginx-forwarder.bicep            # nginx Container App
```

## Naming Convention

All resource names follow the format: `{resource-abbreviation}-{appname}-{locationshort}`

Where:

- `appname`: Application name (parameter)
- `locationshort`: Short code for the location (parameter)

### Abbreviations Used

- `vnet`: Virtual Network
- `afw`: Azure Firewall
- `pip`: Public IP Address
- `cae`: Container App Environment
- `ca`: Container App
- `law`: Log Analytics Workspace
- `umi`: User Assigned Managed Identity
- `st`: Storage Account

## Deployment

To deploy the infrastructure:

```bash
# Create a resource group
az group create --name rg-depolicify-itn --location italynorth

# Deploy the infrastructure
az deployment group create \
  --resource-group <resource-group> \
  --template-file aca-iac/main.bicep \
  --parameters appName=<appname> locationShort=<locationshort> location=<location> forwardDestinationHostname=<hostname> sslCertKvSecretUrl=<kvSecretUrl>
```

## Parameters

The main template parameters are:

- `appName`: Application name (default: "depolicify")
- `locationShort`: Short code for the location (default: "itn")
- `location`: Azure region (default: "italynorth")
- `ports`: Array of ports to expose (default: [8883, 443])
- `forwardDestinationHostname`: Destination hostname for forwarding
- `sslCertKvSecretUrl`: Key Vault Secret URL for SSL certificate
- `cpu`: CPU for the container (default: "0.5")
- `memory`: Memory for the container (default: "1.0Gi")
- `maxReplicas`: Maximum number of replicas (default: 3)
- `zoneRedundant`: Deploy zone-redundant (default: false)

## Notes

- The Container App Environment is configured as Internal, so it is not directly accessible from the Internet
- Public traffic is routed through Azure Firewall, which performs NAT to the Container App on the configured ports
- Configuration files and scripts are uploaded to Azure File Share and mounted in the container
- The solution supports forwarding on multiple TCP ports (e.g., 8883, 443)
