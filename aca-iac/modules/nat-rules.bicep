@description('Application name used in resource naming')
param appName string

@description('Azure Firewall name')
param firewallName string

@description('Firewall public IP address')
param firewallPublicIpAddress string

@description('Ingress Private IP')
param ingressPrivateIp string

@description('Ingress ports for NAT rules')
param ingressPorts array

// NAT Rule Collection for port forwarding
resource natRuleCollection 'Microsoft.Network/azureFirewalls/natRuleCollections@2024-05-01' = {
  name: '${firewallName}/nat-rules-${appName}-nginx'
  properties: {
    priority: 100
    action: {
      type: 'Dnat'
    }
    rules: [for port in ingressPorts: {
        name: 'nginx-forwarder-${port}'
        description: 'Forward traffic from public port ${port} to nginx container app on ${ingressPrivateIp}:${port}'
        sourceAddresses: [
          '*'
        ]
        destinationAddresses: [
          firewallPublicIpAddress
        ]
        destinationPorts: [
          '${port}'
        ]
        protocols: [
          'TCP'
        ]
        translatedAddress: ingressPrivateIp
        translatedPort: '${port}'
      }]
  }
}

// Outputs
output natRuleCollectionName string = natRuleCollection.name
