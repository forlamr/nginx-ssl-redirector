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

@description('Forwarding port list')
param ports array = [
  8883
  443
]

@description('Forward destination hostname')
param forwardDestinationHostname string

@description('Key Vault Secret Uri for SSL certificate')
param sslCertKvSecretUrl string

@description('CPU requirement for the container')
param cpu string = '0.5'

@description('Memory requirement for the container')
param memory string = '1.0Gi'

@description('Maximum number of replicas for the container app')
@minValue(1)
param maxReplicas int = 3

@description('Zone redundant deployment')
param zoneRedundant bool = false

// Deploy a Log Analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
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
  location: location
}

// Deploy a Storage Account for Container App Environment
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${appName}${locationShort}${substring(uniqueString('${subscription().id}-${resourceGroup().id}'), 0, 4)}'
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
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2022-05-01' = {
  parent: storageAccount
  name: 'default'
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
resource fileShareConfig 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = {
  parent: fileServices
  name: 'config'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 102400
  }
}

resource fileShareScripts 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = {
  parent: fileServices
  name: 'scripts'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 102400
  }
}

// Deployment Script to upload the PowerShell file and generate SAS URL
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  dependsOn: [
    fileShareConfig
    fileShareScripts
  ]
  name: 'ds-uploadfiles-${appName}-${locationShort}'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.50.0'
    retentionInterval: 'PT1H'
    timeout: 'PT10M'
    cleanupPreference: 'OnSuccess'
    storageAccountSettings: {
      storageAccountName: storageAccount.name
      storageAccountKey: storageAccount.listKeys().keys[0].value
    }
    #disable-next-line prefer-interpolation
    scriptContent: concat('''
# Get contents
cat << "EOF" > 01-get-certificate.sh
''', loadTextContent('../scripts/01-get-certificate.sh'), '''

EOF

cat << "EOF" > nginx.conf.template
''', loadTextContent('../templates/nginx.conf.template'), '''

EOF

      # Upload the scripts content to share
      echo "- Uploading scripts ..."
      az storage file upload \
        --account-name $STORAGE_ACCOUNT_NAME \
        --account-key $STORAGE_ACCOUNT_KEY \
        --share-name scripts \
        --source 01-get-certificate.sh \
        --path 01-get-certificate.sh
      echo ""

      # Upload the config content to share
      echo "- Uploading config ..."
      az storage file upload \
        --account-name $STORAGE_ACCOUNT_NAME \
        --account-key $STORAGE_ACCOUNT_KEY \
        --share-name config \
        --source nginx.conf.template \
        --path nginx.conf.template
      echo ""

      
    ''')
    environmentVariables: [
      {
        name: 'STORAGE_ACCOUNT_NAME'
        value: storageAccount.name
      }
      {
        name: 'STORAGE_ACCOUNT_ENDPOINT'
        value: storageAccount.properties.primaryEndpoints.blob
      }
      {
        name: 'STORAGE_ACCOUNT_KEY'
        secureValue: storageAccount.listKeys().keys[0].value
      }
    ]
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
    ingressPrivateIp: containerAppEnv.outputs.ingressPrivateIp
    ports: ports
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

// Outputs
output vnetName string = vnet.outputs.vnetName
output firewallPublicIp string = firewall.outputs.firewallPublicIpAddress
output containerAppEnvironmentName string = containerAppEnv.outputs.name
output containerAppEnvironmentIngressPrivateIp string = containerAppEnv.outputs.ingressPrivateIp
output containerAppName string = containerApp.outputs.containerAppName
output umiName string = identity.name
output umiClientId string = identity.properties.clientId
output umiObjectId string = identity.properties.principalId
