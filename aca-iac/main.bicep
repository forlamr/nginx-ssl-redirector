@description('Application name used in resource naming')
@maxLength(15)
@minLength(3)
param appName string

@description('Location short code for resource naming')
@maxLength(3)
@minLength(2)
param locationShort string

@description('Azure region for resource deployment')
param location string = resourceGroup().location

@description('Forwaring port list')
param ports array = [
  8883
  443
]

@description('Forward destination hostname')
param forwardDestinationHostname string

@description('Key Vault Secret Uri for SSL certificate')
param sslCertKvSecretUrl string


@description('cpu requirement for the container')
param cpu string = '0.25'

@description('Memory requirement for the container')
param memory string = '0.5Gi'

@description('Maximum number of replicas for the container app')
@minValue(1)
param maxReplicas int = 3

@description('Zone redundant deployment')
param zoneRedundant bool = false

// Deploy a Log Analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2024-04-01' = {
  name: 'law-${appName}-${locationShort}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Deploy a User Assigned Managed Identity
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'umi-${appName}-${locationShort}'
}

// Deploy a Storage Account for Container App Environment
resource storageAccount 'Microsoft.Storage/storageAccounts@2024-04-01' = {
  name: 'st${appName}${locationShort}sa${substring(uniqueString('${subscription().id}-${resourceGroup().id}'), 0, 4)}'
  location: location
  sku: {
    name: zoneRedundant ? 'Standard_ZRS' : 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

// Deploy File Services in the Storage Account
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
  sku: {
    name: zoneRedundant ? 'Standard_ZRS' : 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    protocolSettings: {
      smb: {}
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Deploy a File Share named 'config' in the Storage Account
resource fileShareConfig 'Microsoft.Storage/storageAccounts/fileServices/shares@2024-04-01' = {
  parent: fileServices
  name: 'config'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 102400
  }
}

resource fileShareScripts 'Microsoft.Storage/storageAccounts/fileServices/shares@2024-04-01' = {
  parent: fileServices
  name: 'scripts'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 102400
  }
}


// Deploy VNet with subnets
module vnet 'modules/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    appName: appName
    locationShort: locationShort
    location: location
  }
}

// Deploy Azure Firewall
module firewall 'modules/firewall.bicep' = {
  name: 'firewall-deployment'
  params: {
    appName: appName
    locationShort: locationShort
    location: location
    firewallSubnetId: vnet.outputs.firewallSubnetId
    firewallMgmtSubnetId: vnet.outputs.firewallMgmtSubnetId
  }
}

// Deploy Container App Environment
module containerAppEnv 'modules/container-app-environment.bicep' = {
  name: 'container-app-env-deployment'
  params: {
    appName: appName
    locationShort: locationShort
    location: location
    acaSubnetId: vnet.outputs.acaSubnetId
    logAnalyticsWorkspaceCustomerId: logAnalyticsWorkspace.properties.customerId
    logAnalyticsPrimaryKey: logAnalyticsWorkspace.listKeys().primarySharedKey
    storageAccountName: storageAccount.name
    storageAccountKey: storageAccount.listKeys().keys[0].value
    readOnlyShares: [
      fileShareConfig.name
      fileShareScripts.name
    ]
    zoneRedundant: zoneRedundant
  }
}

// Deploy Container App
module containerApp 'modules/nginx-forwarder.bicep' = {
  name: 'nginx-forwarder-deployment'
  params: {
    appName: appName
    locationShort: locationShort
    location: location
    containerAppEnvironmentId: containerAppEnv.outputs.id
    ports: ports
    cpu: cpu
    memory: memory
    maxReplicas: zoneRedundant ? max(maxReplicas, 3) : maxReplicas
    forwardDestinationHostname: forwardDestinationHostname
    sslCertKvSecretUrl: sslCertKvSecretUrl
    umiResourceId: identity.id
    umiClientId: identity.properties.clientId
  }
}

// Deploy NAT Rules
module natRules 'modules/nat-rules.bicep' = {
  name: 'nat-rules-deployment'
  params: {
    appName: appName
    firewallName: firewall.outputs.firewallName
    firewallPublicIpAddress: firewall.outputs.firewallPublicIpAddress
    ingressPorts: ports
    ingressPrivateIp: containerAppEnv.outputs.ingressPrivateIp
  }
}

// Outputs
output vnetName string = vnet.outputs.vnetName
output firewallPublicIp string = firewall.outputs.firewallPublicIpAddress
output containerAppEnvironmentName string = containerAppEnv.outputs.name
output containerAppEnvironmentIngressPrivateIp string = containerAppEnv.outputs.ingressPrivateIp
output containerAppName string = containerApp.outputs.containerAppName
