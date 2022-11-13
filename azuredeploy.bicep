param location string = resourceGroup().location

@allowed([ 'dev', 'prd' ])
param environment string

param organizationPrefix string = 'aio'
param sharedResourcesAbbreviation string = 'shr'

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

module insightsModule 'modules/insights.bicep' = {
  name: '${deployment().name}-insights'
  params: {
    location: location
    organizationPrefix: organizationPrefix
    applicationPrefix: sharedResourcesAbbreviation
    environment: environment
  }
}

module keyVault 'modules/keyVault.bicep' = {
  name: '${deployment().name}-keyVault'
  params: {
    location: location
    keyVaultName: 'kv-${organizationPrefix}-${sharedResourcesAbbreviation}-${environment}'
  }
}

module shiftywebapp 'apps/shifty.bicep' = {
  name: '${deployment().name}-app-shifty'
  params: {
    location: location
    organizationPrefix: organizationPrefix
    applicationPrefix: 'shifty'
    environment: environment
    appservicePlanName: appservicePlan.name
    applicationInsightsName: insightsModule.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: insightsModule.outputs.logAnalyticsWorkspaceName
  }
}
