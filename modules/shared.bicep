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

output appServicePlanName string = appservicePlan.name
output logAnalyticsWorkspaceName string = insightsModule.outputs.logAnalyticsWorkspaceName
output applicationInsightsName string = insightsModule.outputs.applicationInsightsName
