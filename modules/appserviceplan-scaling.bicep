@allowed(['dev', 'prd'])
param environment string
param location string = resourceGroup().location

param organizationPrefix string
param sharedResourcesAbbreviation string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${organizationPrefix}${sharedResourcesAbbreviation}scaling${environment}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
  }

  resource blobService 'blobServices' = {
    name: 'default'

    // Flex Consumption runs the function app from a zip package in this container
    resource deploymentContainer 'containers' = {
      name: 'deployments'
    }
  }
}
