@description('Application name used in resource naming')
param appName string

@description('Location short code for resource naming')
param locationShort string

@description('Azure region for resource deployment')
param location string

@description('Firewall subnet ID')
param firewallSubnetId string

@description('Firewall management subnet ID')
param firewallMgmtSubnetId string

// Public IP for Firewall
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-fw-${appName}-${locationShort}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Public IP for Firewall Management
resource firewallMgmtPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-fwmgmt-${appName}-${locationShort}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Azure Firewall Basic
resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: 'afw-${appName}-${locationShort}'
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    ipConfigurations: [
      {
        name: 'firewallIpConfig'
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
    managementIpConfiguration: {
      name: 'firewallMgmtIpConfig'
      properties: {
        subnet: {
          id: firewallMgmtSubnetId
        }
        publicIPAddress: {
          id: firewallMgmtPublicIp.id
        }
      }
    }
  }
}

// Outputs
output firewallName string = firewall.name
output firewallPublicIpAddress string = firewallPublicIp.properties.ipAddress
