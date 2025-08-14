@description('Application name used in resource naming')
param appName string

@description('Location short code for resource naming')
param locationShort string

@description('Azure region for resource deployment')
param location string

@description('Container App Environment ID')
param containerAppEnvironmentId string

@description('Forward destination hostname')
param forwardDestinationHostname string

@description('Key Vault Secret Uri for SSL certificate')
param sslCertKvSecretUrl string

@description('Ports')
param ports array

@description('CPU requirement for the container')
param cpu string = '0.25'

@description('Memory requirement for the container')
param memory string = '0.5Gi'

@description('Minimum number of replicas for the container app')
param maxReplicas int = 3

@description('User Identity')
param umiResourceId string

@description('User Identity Client Id')
param umiClientId string

// Container App running nginx with TCP ingress
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-nginx-forwarder-${appName}-${locationShort}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: json('{ "${umiResourceId}": {} }')
  }
  properties: {
    environmentId: containerAppEnvironmentId
    configuration: {
      ingress: {
        external: true
        targetPort: ports[0]
        transport: 'tcp'
        exposedPort: ports[0]
        additionalPortMappings: [for p in skip(ports,1): {
          external: true
          targetPort: p
            exposedPort: p
        }]
      }
    }
    template: {
      containers: [
        {
          name: 'nginx-forwarder'
          image: 'nginx:latest'
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: [
            {
              name: 'NGINX_ENVSUBST_OUTPUT_DIR'
              value: '/etc/nginx'
            }
            {
              name: 'KV_SECRET_URL'
              value: sslCertKvSecretUrl
            }
            {
              name: 'UMI_CLIENT_ID'
              value: umiClientId
            }
            {
              name: 'IOTHUB_HOSTNAME'
              value: forwardDestinationHostname
            }
          ]
          volumeMounts: [
            {
              volumeName: 'config'
              mountPath: '/etc/nginx/templates'
            }
            {
              volumeName: 'scripts'
              mountPath: '/docker-entrypoint.d/init-scripts'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: maxReplicas
      }
      volumes: [
        {
          name: 'config'
          storageType: 'AzureFile'
          storageName: 'config'
        }
        {
          name: 'scripts'
          storageType: 'AzureFile'
          storageName: 'scripts'
        }
      ]
    }
  }
}

// Outputs
output containerAppName string = containerApp.name
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
