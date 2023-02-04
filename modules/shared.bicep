@allowed([ 'dev', 'prd' ])
param environment string
param location string = resourceGroup().location

param organizationPrefix string
param sharedResourcesAbbreviation string

resource appservicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'asp-${organizationPrefix}-${sharedResourcesAbbreviation}-${environment}'
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
    family: 'B'
    size: 'B1'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    perSiteScaling: true
    reserved: true
  }
}

module insightsModule 'insights.bicep' = {
  name: '${deployment().name}-insights'
  params: {
    location: location
    organizationPrefix: organizationPrefix
    applicationPrefix: sharedResourcesAbbreviation
    environment: environment
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv-${organizationPrefix}-${sharedResourcesAbbreviation}-${environment}'
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

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: 'sql-${organizationPrefix}-${sharedResourcesAbbreviation}-${environment}'
  location: location
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      principalType: 'Group'
      login: 'analogio-admins'
      sid: 'e1fc4d3f-0369-4250-80ad-78fb6ed443b0'
      tenantId: tenant().tenantId
    }
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
    version: '12.0'
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

  resource devOpsAuditingSettings 'devOpsAuditingSettings@2021-11-01' = {
    name: 'default'
    properties: {
      state: 'Enabled'
      isAzureMonitorTargetEnabled: true
    }
  }

  resource symbolicname 'securityAlertPolicies@2021-11-01' = {
    name: 'default'
    properties: {
      emailAccountAdmins: true
      emailAddresses: [
        'alerts@analogio.dk'
      ]
      state: 'Enabled'
    }
  }
}

output appServicePlanName string = appservicePlan.name
output logAnalyticsWorkspaceName string = insightsModule.outputs.logAnalyticsWorkspaceName
output applicationInsightsName string = insightsModule.outputs.applicationInsightsName
output keyvaultName string = keyVault.name
output sqlServerName string = sqlServer.name
