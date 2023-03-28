param environment string

param location string

param keyvaultName string

param organizationPrefix string
param applicationPrefix string

param sharedResourceGroupName string
param appservicePlanName string
param applicationInsightsName string
param logAnalyticsWorkspaceId string

param enableCustomDomain bool = false

var isPrd = environment == 'prd'

var envSettings = isPrd ? loadJsonContent('../prd_settings.json') : loadJsonContent('../dev_settings.json')

var appSettings = array(envSettings.appSettings)
var keyvaultReferences = array(envSettings.keyvaultReferences)

var keyvaultReferencesFormatted = [for item in keyvaultReferences: {
  name: item.name
  value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=${item.secretName})'
}]

var fqdn = '${webapp.name}.analogio.dk'

resource appservicePlan 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: appservicePlanName
  scope: resourceGroup(sharedResourceGroupName)
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
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
    serverFarmId: appservicePlan.id
    enabled: true
    reserved: true
    siteConfig: {
      numberOfWorkers: 1
      alwaysOn: false
      linuxFxVersion: 'DOCKER|ghcr.io/analogio/coffeecard-api:feature-azure-deploy'
      http20Enabled: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      logsDirectorySizeLimit: 100 // MB
      appSettings: union([
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
            value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=DatabaseSettings-ConnectionString)'
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
            value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=MailgunSettings-ApiKey)'
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
            value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=MobilePaySettings-MerchantId)'
          }
          {
            name: 'MobilePaySettings__SubscriptionKey'
            value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=MobilePaySettings-SubscriptionKey)'
          }
          {
            name: 'MobilePaySettings__CertificateName'
            value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=MobilePaySettings-CertificateName)'
          }
          {
            name: 'MobilePaySettings__CertificatePassword'
            value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=MobilePaySettings-CertificatePassword)'
          }
          {
            name: 'MobilePaySettingsV2__ApiUrl'
            value: 'https://invalidurl.test/'
          }
          {
            name: 'MobilePaySettingsV2__ApiKey'
            value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=MobilePaySettingsV2-ApiKey)'
          }
          {
            name: 'MobilePaySettingsV2__ClientId'
            value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=MobilePaySettingsV2-ClientId)'
          }
          {
            name: 'MobilePaySettingsV2__PaymentPointId'
            value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=MobilePaySettingsV2-PaymentPointId)'
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
        ], appSettings, keyvaultReferencesFormatted)
    }
    httpsOnly: true
    redundancyMode: 'None'
    keyVaultReferenceIdentity: 'SystemAssigned'
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

resource diagnosticSettingsWebApp 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'App Service Logs'
  scope: webapp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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

output webappPrincipalId string = webapp.identity.principalId
