param location string = resourceGroup().location

param organizationPrefix string
param applicationPrefix string
param environment string

param sqlServerName string
param logAnalyticsWorkspaceName string

param skuCapacity int
param skuName string
param skuTier string

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' existing = {
  name: sqlServerName

  resource firewallRules 'firewallRules@2021-11-01' = {
    name: 'default'
    properties: {
      endIpAddress: '0.0.0.0' // 0.0.0.0 allows all internal azure ips
      startIpAddress: '0.0.0.0'
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource sqlDb 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: 'sqldb-${organizationPrefix}-${applicationPrefix}-${environment}'
  parent: sqlServer
  location: location
  sku: {
    capacity: skuCapacity
    name: skuName
    tier: skuTier
  }
  properties: {
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
    zoneRedundant: false
  }

  resource auditSettings 'auditingSettings@2021-11-01' = {
    name: 'default'
    properties: {
      state: 'Enabled'
      auditActionsAndGroups: [
        'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
        'FAILED_DATABASE_AUTHENTICATION_GROUP'
        'BATCH_COMPLETED_GROUP'
      ]
      isAzureMonitorTargetEnabled: true
    }
  }

  resource securityAlerts 'securityAlertPolicies@2021-11-01' = {
    name: 'default'
    properties: {
      state: 'Enabled'
      emailAccountAdmins: true
      emailAddresses: [
        'alerts@analogio.dk'
      ]
    }
  }
}

resource diagnosticSettingsSqldb 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Audit Logs'
  scope: sqlDb
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
      {
        category: 'DevOpsOperationsAudit'
        enabled: true
      }
    ]
  }
}
