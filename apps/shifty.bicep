param location string

param environment string

param organizationPrefix string
param applicationPrefix string

param appservicePlanName string
param applicationInsightsName string
param logAnalyticsWorkspaceName string

var fqdn = '${webapp.name}.analogio.dk'

resource appservicePlan 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: appservicePlanName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource webapp 'Microsoft.Web/sites@2022-03-01' = {
  name: 'app-${organizationPrefix}-${applicationPrefix}-${environment}'
  location: location
  kind: 'app,linux,container'
  properties: {
    enabled: true
    serverFarmId: appservicePlan.id
    reserved: true
    siteConfig: {
      numberOfWorkers: 1
      linuxFxVersion: 'DOCKER|shifty'
      alwaysOn: false
      http20Enabled: true
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

  resource config 'config@2022-03-01' = {
    name: 'web'
    properties: {
      numberOfWorkers: 1
      linuxFxVersion: 'DOCKER|shifty'
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
    }
  }

  resource customDomain 'hostNameBindings@2022-03-01' = {
    name: fqdn
    properties: {
      siteName: webapp.name
      hostNameType: 'Verified'
      // sslState is enabled in the webapp managed certificate module deployment
      sslState: 'Disabled'
    }
  }

  // resource builtinDomain 'hostNameBindings@2022-03-01' = {
  //   name: '${webapp.name}.azurewebsites.net'
  //   properties: {
  //     siteName: webapp.name
  //     hostNameType: 'Verified'
  //     sslState: 'SniEnabled'
  //   }
  // }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
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

module webappManagedCertificate '../modules/webappManagedCertificate.bicep' = {
  name: '${deployment().name}-ssl-${fqdn}'
  params: {
    location: location
    appservicePlanName: appservicePlan.name
    webAppName: webapp.name
    fqdn: fqdn
  }
}
