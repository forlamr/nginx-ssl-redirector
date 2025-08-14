@description('Azure region for resource deployment')
param location string

@description('Azure Firewall name')
param policyName string

@description('Firewall public IP address')
param firewallPublicIpAddress string

@description('Ingress Private IP')
param ingressPrivateIp string

@description('Ingress ports for NAT rules')
param ingressPorts array


resource policy 'Microsoft.Network/firewallPolicies@2024-07-01' = {
  name: policyName
  location: location
  properties: {
    sku: {
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
  }
}

resource dnatRuleCollection 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-07-01' = {
  parent: policy
  name: 'DefaultDnatRuleCollectionGroup'
  location: location
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        action: {
          type: 'Dnat'
        }
        rules: [for port in ingressPorts: {
          ruleType: 'NatRule'
          name: 'port-${port}'
          translatedAddress: ingressPrivateIp
          translatedPort: '${port}'
          ipProtocols: [
            'TCP'
          ]
          sourceAddresses: [
            '*'
          ]
          sourceIpGroups: []
          destinationAddresses: [
            firewallPublicIpAddress
          ]
          destinationPorts: [
            '${port}'
          ]
        }]
        name: 'RoutePorts'
        priority: 100
      }
    ]
  }
}

output policyName string = policy.name
output policyId string = policy.id
