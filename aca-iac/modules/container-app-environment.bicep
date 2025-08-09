@description('Application name used in resource naming')
param appName string

@description('Location short code for resource naming')
param locationShort string

@description('Azure region for resource deployment')
param location string

@description('Subnet ID for Container App Environment')
param acaSubnetId string

// Container App Environment (Internal/BYOVNET)
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${appName}-${locationShort}'
  location: location
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: acaSubnetId
      internal: true
    }
    zoneRedundant: false
  }
}

// Outputs
output containerAppEnvironmentId string = containerAppEnv.id
output containerAppEnvironmentName string = containerAppEnv.name
