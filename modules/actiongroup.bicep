@allowed(['dev', 'prd'])
param environment string

param organizationPrefix string
param sharedResourcesAbbreviation string

param groupShortName string = 'IO Devs'
param emailReceivers array
param logicAppReceivers array

resource actiongroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${organizationPrefix}-${sharedResourcesAbbreviation}-${environment}'
  location: 'Global'
  properties: {
    groupShortName: groupShortName
    enabled: true
    emailReceivers: [
      for email in emailReceivers: {
        name: email
        emailAddress: email
        useCommonAlertSchema: true
      }
    ]
    logicAppReceivers: [
      for app in logicAppReceivers: {
        name: app.name
        resourceId: app.ResourceId
        callbackUrl: listCallbackUrl(app.ResourceId, '2019-05-01').value
        useCommonAlertSchema: app.UseCommonAlertSchema
      }
    ]
  }
}
