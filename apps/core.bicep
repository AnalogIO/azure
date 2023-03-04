param location string = resourceGroup().location

param environment string

param organizationPrefix string
param applicationPrefix string

param sharedResourceGroupName string

param appservicePlanName string
param applicationInsightsName string
param logAnalyticsWorkspaceName string
param sqlServerName string

param enableCustomDomain bool = false

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

resource keyvault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyvaultModule.outputs.keyvaultName
  scope: resourceGroup(sharedResourceGroupName)
}

var keyvaultSecretURL = '${reference(keyvault.id, '2022-07-01').properties.vaultUri}/secrets'

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
        {
          name: 'AllowedHosts'
          value: '*'
        }
        {
          name: 'EnvironmentSettings__EnvironmentType'
          value: 'LocalDevelopment'
        }
        {
          name: 'EnvironmentSettings__MinAppVersion'
          value: '2.0.0'
        }
        {
          name: 'EnvironmentSettings__DeploymentUrl'
          value: 'https://localhost:8080/'
        }
        {
          name: 'DatabaseSettings__ConnectionString'
          value: '${keyvaultSecretURL}/DatabaseSettings__ConnectionString'
        }
        {
          name: 'DatabaseSettings__SchemaName'
          value: 'dbo'
        }
        {
          name: 'IdentitySettings__TokenKey'
          value: 'local-development-token'
        }
        {
          name: 'IdentitySettings__AdminToken'
          value: 'local-development-admintoken'
        }
        {
          name: 'MailgunSettings__ApiKey'
          value: '${keyvaultSecretURL}/MailgunSettings__ApiKey'
        }
        {
          name: 'MailgunSettings__Domain'
          value: 'localhost'
        }
        {
          name: 'MailgunSettings__EmailBaseUrl'
          value: 'https://localhost'
        }
        {
          name: 'MailgunSettings__MailgunApiUrl'
          value: 'https://api.mailgun.net/v3'
        }
        {
          name: 'MobilePaySettings__MerchantId'
          value: '${keyvaultSecretURL}/MobilePaySettings__MerchantId'
        }
        {
          name: 'MobilePaySettings__SubscriptionKey'
          value: '${keyvaultSecretURL}/MobilePaySettings__SubscriptionKey'
        }
        {
          name: 'MobilePaySettings__CertificateName'
          value: '${keyvaultSecretURL}/MobilePaySettings__CertificateName'
        }
        {
          name: 'MobilePaySettings__CertificatePassword'
          value: '${keyvaultSecretURL}/MobilePaySettings__CertificatePassword'
        }
        {
          name: 'MobilePaySettingsV2__ApiUrl'
          value: 'https://invalidurl.test/'
        }
        {
          name: 'MobilePaySettingsV2__ApiKey'
          value: '${keyvaultSecretURL}/MobilePaySettingsV2__ApiKey'
        }
        {
          name: 'MobilePaySettingsV2__ClientId'
          value: '${keyvaultSecretURL}/MobilePaySettingsV2__ClientId'
        }
        {
          name: 'MobilePaySettingsV2__PaymentPointId'
          value: '${keyvaultSecretURL}/MobilePaySettingsV2__PaymentPointId'
        }
        {
          name: 'MobilePaySettingsV2__WebhookUrl'
          value: 'https://invalidurl.test/'
        }
        {
          name: 'LoginLimiterSettings__IsEnabled'
          value: 'true'
        }
        {
          name: 'LoginLimiterSettings__MaximumLoginAttemptsWithinTimeOut'
          value: '5'
        }
      ]
    }
    httpsOnly: true
    redundancyMode: 'None'
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
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

module webappManagedCertificate '../modules/webappManagedCertificate.bicep' = if (enableCustomDomain) {
  name: '${deployment().name}-${applicationPrefix}-ssl-${fqdn}'
  params: {
    location: location
    appservicePlanName: appservicePlan.name
    webAppName: webapp.name
    sslState: 'Disabled'
    fqdn: fqdn
    sharedResourceGroupName: sharedResourceGroupName
  }
}

module keyvaultModule '../modules/keyVault.bicep' = {
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
    keyvaultName: keyvaultModule.outputs.keyvaultName
    roleDefinitionId: keyvaultSecretUserRole.id
    principalId: webapp.identity.principalId
  }
}

resource diagnosticSettingsWebApp 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'App Service Logs'
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
