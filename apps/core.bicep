param location string = resourceGroup().location

param environment string

param organizationPrefix string
param applicationPrefix string

param sharedResourceGroupName string

param appservicePlanName string
param applicationInsightsName string
param logAnalyticsWorkspaceName string
param sqlServerName string

var fqdn = '${webapp.name}.analogio.dk'

resource appservicePlan 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: appservicePlanName
  scope: resourceGroup(sharedResourceGroupName)
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
  scope: resourceGroup(sharedResourceGroupName)
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(sharedResourceGroupName)
}

resource webapp 'Microsoft.Web/sites@2022-03-01' = {
  name: 'app-${organizationPrefix}-${applicationPrefix}-${environment}'
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    serverFarmId: appservicePlan.id
    reserved: true
    siteConfig: {
      numberOfWorkers: 1
      alwaysOn: false
      linuxFxVersion: 'DOTNETCORE|6.0'
      http20Enabled: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference(applicationInsights.id, '2015-05-01').InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: reference(applicationInsights.id, '2015-05-01').ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
      ]
    }
    httpsOnly: true
    redundancyMode: 'None'
    keyVaultReferenceIdentity: 'SystemAssigned'
  }

  // resource customDomain 'hostNameBindings@2022-03-01' = {
  //   name: fqdn
  //   properties: {
  //     siteName: webapp.name
  //     hostNameType: 'Verified'
  //     // sslState is enabled in the webapp managed certificate module deployment
  //     sslState: 'Disabled'
  //   }
  // }
}

module sqlDb '../modules/sqldatabase.bicep' = {
  name: '${deployment().name}-${applicationPrefix}-sqldb'
  scope: resourceGroup(sharedResourceGroupName)
  params: {
    organizationPrefix: organizationPrefix
    applicationPrefix: applicationPrefix
    environment: environment
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.name
    sqlServerName: sqlServerName
    skuCapacity: 10
    skuName: 'Standard'
    skuTier: 'Standard'
  }
}

module webappManagedCertificate '../modules/webappManagedCertificate.bicep' = {
  name: '${deployment().name}-${applicationPrefix}-ssl-${fqdn}'
  params: {
    location: location
    appservicePlanName: appservicePlan.name
    webAppName: webapp.name
    sslState: 'Disabled'
    fqdn: fqdn
  }
}

module keyvault '../modules/keyVault.bicep' = {
  name: '${deployment().name}-${applicationPrefix}-kv'
  params: {
    organizationPrefix: organizationPrefix
    applicationPrefix: applicationPrefix
    environment: environment
    sharedResourceGroupName: sharedResourceGroupName
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.name
  }
}

@description('Built-in Key Vault Secrets User role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource keyvaultSecretUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

module webappKeyvaultRoleAssignment '../modules/keyvaultRoleassignment.bicep' = {
  name: '${deployment().name}-${applicationPrefix}-rbac-kvwebapp'
  params: {
    keyvaultName: keyvault.outputs.keyvaultName
    roleDefinitionId: keyvaultSecretUserRole.id
    principalId: webapp.identity.principalId
  }
}

resource diagnosticSettingsWebApp 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Diagnostic Settings'
  scope: webapp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
  }
}
