@description('Application name used in resource naming')
param appName string

@description('Location short code for resource naming')
param locationShort string

@description('Azure region for resource deployment')
param location string

@description('Container App Environment ID')
param containerAppEnvironmentId string

// Container App running nginx with TCP ingress
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-nginx-forwarder-${appName}-${locationShort}'
  location: location
  properties: {
    environmentId: containerAppEnvironmentId
    configuration: {
      ingress: {
        external: true
        targetPort: 8883
        transport: 'tcp'
        exposedPort: 8883
        additionalPortMappings: [
          {
            external: true
            targetPort: 443
            exposedPort: 443
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: 'nginx-forwarder'
          image: 'nginx:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'NGINX_PORT'
              value: '8883'
            }
            {
              name: 'NGINX_SSL_PORT'
              value: '443'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

// Outputs
output containerAppName string = containerApp.name
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
