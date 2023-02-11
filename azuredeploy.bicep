targetScope = 'subscription'

@allowed([ 'dev', 'prd' ])
param environment string

var location = 'West Europe'

var organizationPrefix = 'aio'
var sharedResourcesAbbreviation = 'shr'
var webAppResourcesAbbreviation = 'app'

var config = {
  dev: {
    core: {}
    shiftapi: {}
    shifty: {
      customDomainName: 'dev.shifty.analogio.dk'
    }
  }
  prd: {
    core: {}
    shiftapi: {}
    shifty: {
      customDomainName: 'shifty.analogio.dk'
    }
  }
}

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
    sharedResourceGroupName: sharedRg.name
    appservicePlanName: sharedResources.outputs.appServicePlanName
    applicationInsightsName: sharedResources.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: sharedResources.outputs.logAnalyticsWorkspaceName
    sqlServerName: sharedResources.outputs.sqlServerName
  }
}

resource shiftplanningApiRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${organizationPrefix}-${webAppResourcesAbbreviation}-shiftapi-${environment}'
  location: location
}

module shiftplanningApiwebapp 'apps/shiftplanningApi.bicep' = {
  name: '${deployment().name}-app-shiftapi'
  scope: shiftplanningApiRg
  params: {
    location: location
    organizationPrefix: organizationPrefix
    applicationPrefix: 'shiftapi'
    environment: environment
    sharedResourceGroupName: sharedRg.name
    appservicePlanName: sharedResources.outputs.appServicePlanName
    applicationInsightsName: sharedResources.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: sharedResources.outputs.logAnalyticsWorkspaceName
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
    sharedResourceGroupName: sharedRg.name
    applicationInsightsName: sharedResources.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: sharedResources.outputs.logAnalyticsWorkspaceName
    customDomainFqdn: config[environment].shifty.customDomainName
  }
}
