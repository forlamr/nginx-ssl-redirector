@description('Application name used in resource naming')
param appName string

@description('Azure Firewall name')
param firewallName string

@description('Firewall public IP address')
param firewallPublicIpAddress string

// NAT Rule Collection for port forwarding
resource natRuleCollection 'Microsoft.Network/azureFirewalls/natRuleCollections@2024-05-01' = {
  name: '${firewallName}/nat-rules-${appName}'
  properties: {
    priority: 100
    action: {
      type: 'Dnat'
    }
    rules: [
      {
        name: 'nginx-forwarder-8883'
        description: 'Forward traffic from public port 8883 to nginx container app on 10.0.1.57:8883'
        sourceAddresses: [
          '*'
        ]
        destinationAddresses: [
          firewallPublicIpAddress
        ]
        destinationPorts: [
          '8883'
        ]
        protocols: [
          'TCP'
        ]
        translatedAddress: '10.0.1.57'
        translatedPort: '8883'
      }
      {
        name: 'nginx-forwarder-443'
        description: 'Forward traffic from public port 443 to nginx container app on 10.0.1.57:443'
        sourceAddresses: [
          '*'
        ]
        destinationAddresses: [
          firewallPublicIpAddress
        ]
        destinationPorts: [
          '443'
        ]
        protocols: [
          'TCP'
        ]
        translatedAddress: '10.0.1.57'
        translatedPort: '443'
      }
    ]
  }
}

// Outputs
output natRuleCollectionName string = natRuleCollection.name
