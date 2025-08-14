@description('Application name used in resource naming')
param appName string

@description('Location short code for resource naming')
param locationShort string

@description('Azure region for resource deployment')
param location string

@description('Subnet ID for Container App Environment')
param acaSubnetId string

@description('Zone redundant deployment')
param zoneRedundant bool = false

@description('Log Analytics Workspace ID for Container App Environment')
param logAnalyticsWorkspaceCustomerId string

@description('Log Analytics Primary Key for Container App Environment')
param logAnalyticsPrimaryKey string

@description('Storage Account Name for Azure File mounts')
param storageAccountName string

@description('Storage Account Key for Azure File mounts')
@secure()
param storageAccountKey string

@description('Storage Shares to mount in Container App Environment')
param readOnlyShares array

// Container App Environment (Internal/BYOVNET)
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${appName}-${locationShort}'
  location: location
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: acaSubnetId
      internal: true
    }
    zoneRedundant: zoneRedundant
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceCustomerId
        sharedKey: logAnalyticsPrimaryKey
        dynamicJsonColumns: false
      }
    }

  }
}

// Azure File shares
resource containerAppEnvShares 'Microsoft.App/managedEnvironments/storages@2025-02-02-preview' = [for share in readOnlyShares: {
  parent: containerAppEnv
  name: share
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: share
      accessMode: 'ReadOnly'
    }
  }
}]

// Outputs
output id string = containerAppEnv.id
output name string = containerAppEnv.name
output ingressPrivateIp string = containerAppEnv.properties.staticIp
