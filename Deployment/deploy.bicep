param prefix string
param appEnvironment string
param branch string
param location string = 'centralus'
@secure()
param sqlPassword string
param keyVaultName string
param managedIdentityId string
param version string
param enableAppGateway string
param subnetId string

var stackName = '${prefix}${appEnvironment}'

var identity = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${managedIdentityId}': {}
  }
}

var tags = {
  'stack-name': 'contoso-customer-service-app-service'
  'stack-environment': appEnvironment
  'stack-version': version
  'stack-branch': branch
}

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: stackName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    ImmediatePurgeDataOn30Days: true
    IngestionMode: 'ApplicationInsights'
  }
}

resource str 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: stackName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

var strConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${stackName};AccountKey=${listKeys(str.id, str.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'

resource strqueue 'Microsoft.Storage/storageAccounts/queueServices@2021-04-01' = {
  name: 'default'
  parent: str
}

var queueName = 'orders'
resource strqueuename 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-04-01' = {
  name: queueName
  parent: strqueue
}

var sqlUsername = 'app'

resource sql 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: stackName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlUsername
    administratorLoginPassword: sqlPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

var dbName = 'app'
resource db 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name: dbName
  parent: sql
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

resource sqlfw 'Microsoft.Sql/servers/firewallRules@2021-02-01-preview' = {
  parent: sql
  name: 'AllowAllMicrosoftAzureIps'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

var appPlanName = 'B1'
// Customer service website
var csapp = '${stackName}csapp'
resource csappplan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: csapp
  location: location
  tags: tags
  sku: {
    name: appPlanName
  }
}

resource csappsite 'Microsoft.Web/sites@2021-01-15' = {
  name: csapp
  location: location
  tags: tags
  identity: identity
  properties: {
    keyVaultReferenceIdentity: managedIdentityId
    serverFarmId: csappplan.id
    httpsOnly: true
    siteConfig: {
      healthCheckPath: '/health'
      netFrameworkVersion: 'v6.0'
      #disable-next-line BCP037
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'
        }
      ]
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appinsights.properties.InstrumentationKey
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
        {
          name: 'DiagnosticServices_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
          value: 'disabled'
        }
        {
          name: 'APPINSIGHTS_SNAPSHOTFEATURE_VERSION'
          value: '1.0.0'
        }
        {
          name: 'InstrumentationEngine_EXTENSION_VERSION'
          value: '~1'
        }
        {
          name: 'SnapshotDebugger_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_BaseExtensions'
          value: '~1'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Development'
        }
        {
          name: 'DbSource'
          value: sql.properties.fullyQualifiedDomainName
        }
        {
          name: 'DbName'
          value: dbName
        }
        {
          name: 'DbUserId'
          value: sqlUsername
        }
        {
          name: 'DbPassword'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-sql-password)'
        }
        {
          name: 'EnableAuth'
          value: 'true'
        }
        {
          name: 'AzureAd:CallbackPath'
          value: '/signin-oidc'
        }
        {
          name: 'AzureAd:Instance'
          value: environment().authentication.loginEndpoint
        }
        {
          name: 'AzureAd:TenantId'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-tenant-id)'
        }
        {
          name: 'AzureAd:Domain'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-domain)'
        }
        {
          name: 'AzureAd:ClientId'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-client-id)'
        }
        {
          name: 'AzureAd:ClientSecret'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-client-secret)'
        }
        {
          name: 'AlternateIdServiceUri'
          value: 'https://${altidapp}.azurewebsites.net'
        }
        {
          name: 'PartnerAPIUri'
          value: 'https://${partapiapp}.azurewebsites.net'
        }
        {
          name: 'OverrideAuthRedirectHostName'
          value: (enableAppGateway == 'true') ? 'https://demo.contoso.com/signin-oidc' : ''
        }
      ]
    }
  }
}

var altidapp = '${stackName}altidapp'
resource altidappplan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: altidapp
  location: location
  tags: tags
  sku: {
    name: appPlanName
  }
}

resource altidappsite 'Microsoft.Web/sites@2021-01-15' = {
  name: altidapp
  location: location
  tags: tags
  identity: identity
  properties: {
    keyVaultReferenceIdentity: managedIdentityId
    serverFarmId: altidappplan.id
    httpsOnly: true
    siteConfig: {
      healthCheckPath: '/health'
      netFrameworkVersion: 'v6.0'
      #disable-next-line BCP037
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'
        }
      ]
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appinsights.properties.InstrumentationKey
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
        {
          name: 'DiagnosticServices_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
          value: 'disabled'
        }
        {
          name: 'APPINSIGHTS_SNAPSHOTFEATURE_VERSION'
          value: '1.0.0'
        }
        {
          name: 'InstrumentationEngine_EXTENSION_VERSION'
          value: '~1'
        }
        {
          name: 'SnapshotDebugger_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_BaseExtensions'
          value: '~1'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Development'
        }
        {
          name: 'DbSource'
          value: sql.properties.fullyQualifiedDomainName
        }
        {
          name: 'DbName'
          value: dbName
        }
        {
          name: 'DbUserId'
          value: sqlUsername
        }
        {
          name: 'DbPassword'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-sql-password)'
        }
      ]
    }
  }
}

var partapiapp = '${stackName}partapiapp'
resource partapiappplan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: partapiapp
  location: location
  tags: tags
  sku: {
    name: appPlanName
  }
}

resource partapiappsite 'Microsoft.Web/sites@2021-01-15' = {
  name: partapiapp
  location: location
  tags: tags
  identity: identity
  properties: {
    keyVaultReferenceIdentity: managedIdentityId
    serverFarmId: partapiappplan.id
    httpsOnly: true
    siteConfig: {
      healthCheckPath: '/health'
      netFrameworkVersion: 'v6.0'
      #disable-next-line BCP037
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'
        }
      ]
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appinsights.properties.InstrumentationKey
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
        {
          name: 'DiagnosticServices_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
          value: 'disabled'
        }
        {
          name: 'APPINSIGHTS_SNAPSHOTFEATURE_VERSION'
          value: '1.0.0'
        }
        {
          name: 'InstrumentationEngine_EXTENSION_VERSION'
          value: '~1'
        }
        {
          name: 'SnapshotDebugger_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_BaseExtensions'
          value: '~1'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Development'
        }
        {
          name: 'DbSource'
          value: sql.properties.fullyQualifiedDomainName
        }
        {
          name: 'DbName'
          value: dbName
        }
        {
          name: 'DbUserId'
          value: sqlUsername
        }
        {
          name: 'DbPassword'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-sql-password)'
        }
        {
          name: 'ShippingRepositoryType'
          value: 'Storage'
        }
        {
          name: 'QueueName'
          value: queueName
        }
        {
          name: 'QueueConnectionString'
          value: strConnectionString
        }
        {
          name: 'DisableQueueDelay'
          value: 'true'
        }
      ]
    }
  }
}

var backendapp = '${stackName}backendapp'
resource backendappStr 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: backendapp
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
  tags: tags
}

resource backendappplan 'Microsoft.Web/serverfarms@2020-10-01' = {
  name: backendapp
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

var backendappConnection = 'DefaultEndpointsProtocol=https;AccountName=${backendappStr.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(backendappStr.id, backendappStr.apiVersion).keys[0].value}'
resource backendfuncapp 'Microsoft.Web/sites@2020-12-01' = {
  name: backendapp
  location: location
  tags: tags
  kind: 'functionapp'
  identity: identity
  properties: {
    keyVaultReferenceIdentity: managedIdentityId
    httpsOnly: true
    serverFarmId: backendappplan.id
    clientAffinityEnabled: true
    siteConfig: {
      webSocketsEnabled: true
      appSettings: [
        {
          'name': 'APPINSIGHTS_INSTRUMENTATIONKEY'
          'value': appinsights.properties.InstrumentationKey
        }
        {
          name: 'DbSource'
          value: sql.properties.fullyQualifiedDomainName
        }
        {
          name: 'DbName'
          value: dbName
        }
        {
          name: 'DbUserId'
          value: sqlUsername
        }
        {
          name: 'DbPassword'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-sql-password)'
        }
        {
          'name': 'AzureWebJobsDashboard'
          'value': backendappConnection
        }
        {
          'name': 'AzureWebJobsStorage'
          'value': backendappConnection
        }
        {
          'name': 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          'value': backendappConnection
        }
        {
          'name': 'WEBSITE_CONTENTSHARE'
          'value': 'functions2021'
        }
        {
          'name': 'QueueName'
          'value': queueName
        }
        {
          'name': 'Connection'
          'value': strConnectionString
        }
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'dotnet'
        }
        {
          'name': 'FUNCTIONS_EXTENSION_VERSION'
          'value': '~4'
        }
        {
          'name': 'ApplicationInsightsAgent_EXTENSION_VERSION'
          'value': '~2'
        }
        {
          'name': 'XDT_MicrosoftApplicationInsights_Mode'
          'value': 'default'
        }
      ]
    }
  }
}

output cs string = csapp
output altid string = altidapp
output partapi string = partapiapp
output backend string = backendapp
output sqlserver string = sql.properties.fullyQualifiedDomainName
output sqlusername string = sqlUsername
output dbname string = dbName

resource appGwIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = if (enableAppGateway == 'true') {
  name: stackName
  location: location
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'contoso-customer-service-${stackName}'
    }
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

var csappsiteFqdn = '${csappsite.name}.azurewebsites.net'
var appGwId = resourceId('Microsoft.Network/applicationGateways', stackName)

resource appGw 'Microsoft.Network/applicationGateways@2021-05-01' = if (enableAppGateway == 'true') {
  name: stackName
  location: location
  tags: tags
  identity: identity
  properties: {
    sslCertificates: [
      {
        name: 'appgwcert'
        properties: {
          keyVaultSecretId: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/appgwcert'
        }
      }
    ]
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    autoscaleConfiguration: {
      minCapacity: 1
      maxCapacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: appGwIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'customer-service'
        properties: {
          backendAddresses: [
            {
              fqdn: csappsiteFqdn
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'customer-service-app-https-setting'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: csappsiteFqdn
          pickHostNameFromBackendAddress: false
          affinityCookieName: 'ApplicationGatewayAffinity'
          requestTimeout: 20
          probe: {
            id: '${appGwId}/probes/customer-service-app-https-setting-probe'
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'customer-service-app'
        properties: {
          frontendIPConfiguration: {
            id: '${appGwId}/frontendIPConfigurations/appGwPublicFrontendIp'
          }
          frontendPort: {
            id: '${appGwId}/frontendPorts/port_80'
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'frontend-to-customer-service-app'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: '${appGwId}/httpListeners/customer-service-app'
          }
          backendAddressPool: {
            id: '${appGwId}/backendAddressPools/customer-service'
          }
          backendHttpSettings: {
            id: '${appGwId}/backendHttpSettingsCollection/customer-service-app-https-setting'
          }
        }
      }
    ]
    probes: [
      {
        name: 'customer-service-app-https-setting-probe'
        properties: {
          protocol: 'Https'
          host: csappsiteFqdn
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
    }
  }
}
