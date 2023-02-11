param location string = resourceGroup().location

param environment string

param organizationPrefix string
param applicationPrefix string

param sharedResourceGroupName string

param applicationInsightsName string
param logAnalyticsWorkspaceName string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
  scope: resourceGroup(sharedResourceGroupName)
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(sharedResourceGroupName)
}

resource staticwebapp 'Microsoft.Web/staticSites@2022-03-01' = {
  name: 'stapp-${organizationPrefix}-${applicationPrefix}-${environment}'
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    allowConfigFileUpdates: false
    repositoryUrl: 'https://github.com/AnalogIO/shifty-webapp'
    branch: 'develop'
    provider: 'GitHub'
    stagingEnvironmentPolicy: 'Disabled'
    enterpriseGradeCdnStatus: 'Disabled'
  }
}
