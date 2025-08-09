@description('Application name used in resource naming')
param appName string

@description('Location short code for resource naming')
param locationShort string

@description('Azure region for resource deployment')
param location string = resourceGroup().location

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
  }
}

// Deploy Container App
module containerApp 'modules/container-app.bicep' = {
  name: 'container-app-deployment'
  params: {
    appName: appName
    locationShort: locationShort
    location: location
    containerAppEnvironmentId: containerAppEnv.outputs.containerAppEnvironmentId
  }
  dependsOn: [
    firewall
  ]
}

// Deploy NAT Rules
module natRules 'modules/nat-rules.bicep' = {
  name: 'nat-rules-deployment'
  params: {
    appName: appName
    firewallName: firewall.outputs.firewallName
    firewallPublicIpAddress: firewall.outputs.firewallPublicIpAddress
  }
  dependsOn: [
    containerApp
  ]
}

// Outputs
output vnetName string = vnet.outputs.vnetName
output firewallPublicIp string = firewall.outputs.firewallPublicIpAddress
output containerAppEnvironmentName string = containerAppEnv.outputs.containerAppEnvironmentName
output containerAppName string = containerApp.outputs.containerAppName
