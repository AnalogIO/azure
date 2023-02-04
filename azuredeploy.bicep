targetScope = 'subscription'

@allowed([ 'dev', 'prd' ])
param environment string

var location = 'West Europe'
var organizationPrefix = 'aio'
var sharedResourcesAbbreviation = 'shr'
var webAppResourcesAbbreviation = 'app'

resource sharedRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${organizationPrefix}-${sharedResourcesAbbreviation}-${environment}'
  location: location
}

module sharedResources 'modules/shared.bicep' = {
  name: '${deployment().name}-shared'
  scope: sharedRg
  params: {
    location: location
    environment: environment
    organizationPrefix: organizationPrefix
    sharedResourcesAbbreviation: sharedResourcesAbbreviation
  }
}

resource coreRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${organizationPrefix}-${webAppResourcesAbbreviation}-core-${environment}'
  location: location
}

module corewebapp 'apps/core.bicep' = {
  name: '${deployment().name}-app-core'
  scope: coreRg
  params: {
    location: location
    organizationPrefix: organizationPrefix
    applicationPrefix: 'core'
    environment: environment
    appservicePlanName: sharedResources.outputs.appServicePlanName
    applicationInsightsName: sharedResources.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: sharedResources.outputs.logAnalyticsWorkspaceName
    keyvaultName: sharedResources.outputs.keyvaultName
    sqlServerName: sharedResources.outputs.sqlServerName
  }
}

resource shiftplanningApiRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${organizationPrefix}-${webAppResourcesAbbreviation}-shiftapi-${environment}'
  location: location
}

module shiftplanningApiwebapp 'apps/shiftplanningApi.bicep' = {
  name: '${deployment().name}-app-core'
  scope: shiftplanningApiRg
  params: {
    location: location
    organizationPrefix: organizationPrefix
    applicationPrefix: 'shiftapi'
    environment: environment
    appservicePlanName: sharedResources.outputs.appServicePlanName
    applicationInsightsName: sharedResources.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: sharedResources.outputs.logAnalyticsWorkspaceName
    keyvaultName: sharedResources.outputs.keyvaultName
    sqlServerName: sharedResources.outputs.sqlServerName
  }
}

resource shiftyRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${organizationPrefix}-${webAppResourcesAbbreviation}-shifty-${environment}'
  location: location
}

module shiftywebapp 'apps/shifty.bicep' = {
  name: '${deployment().name}-app-shifty'
  scope: shiftyRg
  params: {
    location: location
    organizationPrefix: organizationPrefix
    applicationPrefix: 'shifty'
    environment: environment
    appservicePlanName: sharedResources.outputs.appServicePlanName
    applicationInsightsName: sharedResources.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: sharedResources.outputs.logAnalyticsWorkspaceName
  }
}
