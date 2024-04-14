@allowed(['dev', 'prd'])
param environment string
param location string = resourceGroup().location

param organizationPrefix string
param sharedResourcesAbbreviation string

var slackConnectionName = 'CafeAnalog'

@description('The Slack channel to post to')
param slackChannel string = 'io-alerts'

var connectionId = subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'slack')
resource slackConnection 'Microsoft.Web/connections@2016-06-01' = {
  location: location
  name: slackConnectionName
  properties: {
    api: {
      id: connectionId
    }
    displayName: slackConnectionName
  }
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'logic-${organizationPrefix}-${sharedResourcesAbbreviation}-${environment}'
  location: location
  properties: {
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      actions: {
        'Post_message_(V2)': {
          inputs: {
            body: {
              channel: slackChannel
              text: ':rotating_light: :rotating_light: *Azure alert `@{triggerBody()?[\'data\']?[\'essentials\']?[\'alertRule\']}` (severity @{triggerBody()?[\'data\']?[\'essentials\']?[\'severity\']}) is @{triggerBody()?[\'data\']?[\'essentials\']?[\'monitorCondition\']}*\n\nAffected Resources\n```\n@{join(triggerBody()?[\'data\']?[\'essentials\']?[\'alertTargetIDs\'], \'\n\')}\n```\n'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'slack\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/chat.postMessage'
          }
          runAfter: {}
          type: 'ApiConnection'
        }
      }
      contentVersion: '1.0.0.0'
      outputs: {}
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        HTTP_Request: {
          inputs: {
            schema: {
              properties: {
                data: {
                  properties: {
                    alertContext: {
                      properties: {}
                      type: 'object'
                    }
                    essentials: {
                      properties: {
                        alertContextVersion: {
                          type: 'string'
                        }
                        alertId: {
                          type: 'string'
                        }
                        alertRule: {
                          type: 'string'
                        }
                        alertTargetIDs: {
                          items: {
                            type: 'string'
                          }
                          type: 'array'
                        }
                        description: {
                          type: 'string'
                        }
                        essentialsVersion: {
                          type: 'string'
                        }
                        firedDateTime: {
                          type: 'string'
                        }
                        monitorCondition: {
                          type: 'string'
                        }
                        monitoringService: {
                          type: 'string'
                        }
                        originAlertId: {
                          type: 'string'
                        }
                        resolvedDateTime: {
                          type: 'string'
                        }
                        severity: {
                          type: 'string'
                        }
                        signalType: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                  }
                  type: 'object'
                }
                schemaId: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
          kind: 'Http'
          operationOptions: 'EnableSchemaValidation'
          type: 'Request'
        }
      }
    }
    parameters: {
      '$connections': {
        value: {
          slack: {
            connectionId: slackConnection.id
            connectionName: slackConnection.name
            id: connectionId
          }
        }
      }
    }
  }
}

output logicAppName string = logicApp.name
output logicAppResourceId string = logicApp.id
