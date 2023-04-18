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

var isPrd = environment == 'prd'

var envSettings = isPrd ? loadJsonContent('prd_settings.json') : loadJsonContent('dev_settings.json')

var appSettings = array(envSettings.appSettings)
var keyVaultReferences = array(envSettings.keyVaultReferences)

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(sharedResourceGroupName)
}

var keyvaultName = keyvaultModule.outputs.keyvaultName

module webapp '../../modules/webapp.bicep' = {
  name: '${deployment().name}-${applicationPrefix}-webapp'
  scope: resourceGroup(sharedResourceGroupName)
  params: {
    organizationPrefix: organizationPrefix
    applicationPrefix: applicationPrefix
    environment: environment
    location: location
    appservicePlanName: appservicePlanName
    sharedResourceGroupName: sharedResourceGroupName
    applicationInsightsName: applicationInsightsName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
    enableCustomDomain: enableCustomDomain
    keyvaultName: keyvaultName
    appSettings: appSettings
    keyVaultReferences: keyVaultReferences
  }
}

module sqlDb '../../modules/sqldatabase.bicep' = {
  name: '${deployment().name}-${applicationPrefix}-sqldb'
  scope: resourceGroup(sharedResourceGroupName)
  params: {
    organizationPrefix: organizationPrefix
    applicationPrefix: applicationPrefix
    environment: environment
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.name
    sqlServerName: sqlServerName
    skuCapacity: 10
    skuName: 'Standard'
    skuTier: 'Standard'
  }
}

module keyvaultModule '../../modules/keyVault.bicep' = {
  name: '${deployment().name}-${applicationPrefix}-kv'
  params: {
    organizationPrefix: organizationPrefix
    applicationPrefix: applicationPrefix
    environment: environment
    location: location
    sharedResourceGroupName: sharedResourceGroupName
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.name
  }
}

@description('Built-in Key Vault Secrets User role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource keyvaultSecretUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

module webappKeyvaultRoleAssignment '../../modules/keyvaultRoleassignment.bicep' = {
  name: '${deployment().name}-${applicationPrefix}-rbac-kvwebapp'
  params: {
    keyvaultName: keyvaultModule.outputs.keyvaultName
    roleDefinitionId: keyvaultSecretUserRole.id
    principalId: webapp.outputs.webappPrincipalId
  }
}
