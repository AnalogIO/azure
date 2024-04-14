targetScope = 'subscription'

@allowed(['dev', 'prd'])
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

resource shiftyRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${organizationPrefix}-${webAppResourcesAbbreviation}-shifty-${environment}'
  location: location
}

module dns 'modules/dns.bicep' = {
  name: '${deployment().name}-dns'
  scope: sharedRg
  params: {
    environment: environment
  }
}

module alertLogicApp 'modules/alert-logicapp.bicep' = {
  name: '${deployment().name}-alert-logic-app'
  scope: sharedRg
  params: {
    organizationPrefix: organizationPrefix
    sharedResourcesAbbreviation: sharedResourcesAbbreviation
    environment: environment
  }
}

module actionGroup 'modules/actiongroup.bicep' = {
  name: '${deployment().name}-actiongroup'
  scope: sharedRg
  params: {
    organizationPrefix: organizationPrefix
    sharedResourcesAbbreviation: sharedResourcesAbbreviation
    environment: environment
    emailReceivers: ['support@analogio.dk']
    logicAppReceivers: [
      {
        name: alertLogicApp.outputs.logicAppName
        resourceId: alertLogicApp.outputs.logicAppResourceId
        callbackUrl: alertLogicApp.outputs.logicAppCallbackUrl
        useCommonAlertSchema: true
      }
    ]
  }
}
