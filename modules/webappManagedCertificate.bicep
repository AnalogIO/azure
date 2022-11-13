param location string

param appservicePlanName string
param webAppName string

param fqdn string

resource appservicePlan 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: appservicePlanName
}

resource webapp 'Microsoft.Web/sites@2022-03-01' existing = {
  name: webAppName
}

resource certificate 'Microsoft.Web/certificates@2022-03-01' = {
  name: '${webAppName}-${fqdn}'
  location: location
  properties: {
    serverFarmId: appservicePlan.id
    canonicalName: fqdn
  }
}

resource customDomain 'Microsoft.web/sites/hostnameBindings@2019-08-01' = {
  parent: webapp
  name: fqdn
  properties: {
    siteName: webapp.name
    hostNameType: 'Verified'
    sslState: 'SniEnabled'
    thumbprint: certificate.properties.thumbprint
  }
}
