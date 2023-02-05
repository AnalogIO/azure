param location string = resourceGroup().location

param organizationPrefix string
param applicationPrefix string
param environment string

param logAnalyticsWorkspaceName string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv-${organizationPrefix}-${applicationPrefix}-${environment}'
  location: location
  properties: {
    enableRbacAuthorization: true
    tenantId: tenant().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    enableSoftDelete: true
    enablePurgeProtection: true
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Audit'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
  }
}

output keyvaultName string = keyVault.name
