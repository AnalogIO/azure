@allowed(['dev', 'prd'])
param environment string
param location string = resourceGroup().location

param organizationPrefix string
param sharedResourcesAbbreviation string

param appservicePlanName string
param applicationInsightsName string
param actionGroupId string

@description('Overrides of the schedule. A setting that is left out uses the default in the function code.')
param scaling {
  timeZone: string?
  peakStartHour: int?
  peakEndHour: int?
  peakSku: string?
  offPeakSku: string?
}

var scalingAppSettings = filter(
  [
    { name: 'Scaling__TimeZone', value: scaling.?timeZone }
    { name: 'Scaling__PeakStartHour', value: scaling.?peakStartHour }
    { name: 'Scaling__PeakEndHour', value: scaling.?peakEndHour }
    { name: 'Scaling__PeakSku', value: scaling.?peakSku }
    { name: 'Scaling__OffPeakSku', value: scaling.?offPeakSku }
  ],
  setting => setting.value != null
)

resource appservicePlan 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: appservicePlanName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

@description('Built-in Storage Blob Data Owner role')
resource storageBlobDataOwnerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
}

@description('Built-in Web Plan Contributor role')
resource webPlanContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '2cc479cb-7b4d-49a8-b449-8c00fd0f0a4b'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${organizationPrefix}${sharedResourcesAbbreviation}scaling${environment}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
  }

  resource blobService 'blobServices' = {
    name: 'default'

    // Flex Consumption runs the function app from a zip package in this container
    resource deploymentContainer 'containers' = {
      name: 'deployments'
    }
  }
}

resource functionPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'asp-${organizationPrefix}-${sharedResourcesAbbreviation}-scaling-${environment}'
  location: location
  kind: 'functionapp'
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: 'func-${organizationPrefix}-${sharedResourcesAbbreviation}-scaling-${environment}'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: functionPlan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}${storageAccount::blobService::deploymentContainer.name}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 1
        instanceMemoryMB: 512
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '10.0'
      }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: concat(
        [
          {
            name: 'AzureWebJobsStorage__accountName'
            value: storageAccount.name
          }
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: applicationInsights.properties.ConnectionString
          }
          {
            name: 'Scaling__PlanResourceId'
            value: appservicePlan.id
          }
        ],
        map(scalingAppSettings, setting => { name: setting.name, value: string(setting.value) })
      )
    }
  }
}

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, storageBlobDataOwnerRole.id)
  properties: {
    roleDefinitionId: storageBlobDataOwnerRole.id
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource planRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appservicePlan
  name: guid(appservicePlan.id, functionApp.id, webPlanContributorRole.id)
  properties: {
    roleDefinitionId: webPlanContributorRole.id
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource failedRunsAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: 'alert-failedruns-${functionApp.name}'
  location: location
  properties: {
    description: 'A run of the function that scales App Service plan ${appservicePlan.name} failed'
    severity: 2
    enabled: true
    autoMitigate: true
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT15M'
    windowSize: 'PT1H'
    criteria: {
      allOf: [
        {
          query: 'requests | where cloud_RoleName =~ "${functionApp.name}" and success == false'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
    }
  }
}

// A function app that cannot start never logs a failed run, so alert when the hourly runs stop too
resource missingRunsAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: 'alert-missingruns-${functionApp.name}'
  location: location
  properties: {
    description: 'The function that scales App Service plan ${appservicePlan.name} has not run for 2 hours'
    severity: 2
    enabled: true
    autoMitigate: true
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT1H'
    windowSize: 'PT2H'
    criteria: {
      allOf: [
        {
          query: 'requests | where cloud_RoleName =~ "${functionApp.name}" | summarize Runs = count()'
          timeAggregation: 'Total'
          metricMeasureColumn: 'Runs'
          operator: 'LessThan'
          threshold: 1
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
    }
  }
}

output functionAppName string = functionApp.name
