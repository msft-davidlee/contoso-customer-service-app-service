param prefix string
param appEnvironment string
param branch string
param location string = 'centralus'
param sharedResourceGroup string
param keyVaultName string
param managedIdentityId string
param version string
param enableAppGateway string
param subnetId string
param enableFrontdoor string
param enableAPIM string
param stackTagName string
param appVersion string
param buildAccountName string
param utc string = utcNow()

var stackName = '${prefix}${appEnvironment}'

var identity = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${managedIdentityId}': {}
  }
}

var tags = {
  'stack-name': stackTagName
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

//https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/key-vault-parameter?tabs=azure-cli#use-getsecret-function

resource kv 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyVaultName
  scope: resourceGroup(subscription().subscriptionId, sharedResourceGroup)
}

module sql './sql.bicep' = {
  name: 'deploySQL'
  params: {
    stackName: stackName
    sqlPassword: kv.getSecret('contoso-customer-service-sql-password')
    tags: tags
    location: location
  }
}

var appPlanName = 'S1'
// Customer service website
var webapp = '${stackName}web'
resource webappplan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: webapp
  location: location
  tags: tags
  sku: {
    name: appPlanName
  }
}

var storageAccountUri = 'https://${buildAccountName}.blob.${environment().suffixes.storage}/apps/contoso-demo'
var sasExp = dateTimeAdd(utc, 'P90D')
var sas = listServiceSAS(buildAccountName, '2021-04-01', {
  canonicalizedResource: '/blob/${buildAccountName}/apps'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'rl'
  signedServices: 'b'
  signedExpiry: sasExp
})

module csappdeploy './appdeploy.bicep' = {
  name: 'deployCustomerService'
  params: {
    uri: '${storageAccountUri}-website-${appVersion}.zip?${sas}'
    parentName: csapp
  }
}

var csapp = '${stackName}csapp'
resource csappsite 'Microsoft.Web/sites@2021-01-15' = {
  name: csapp
  location: location
  tags: tags
  identity: identity
  properties: {
    keyVaultReferenceIdentity: managedIdentityId
    serverFarmId: webappplan.id
    httpsOnly: true
    siteConfig: {
      http20Enabled: true
      minTlsVersion: '1.2'
      ipSecurityRestrictions: (enableAppGateway == 'true') ? [
        {
          vnetSubnetResourceId: subnetId
          action: 'Allow'
          tag: 'Default'
          priority: 200
          name: 'AllowAppGatewaySubnet'
        }
      ] : (enableFrontdoor == 'true') ? [
        {
          ipAddress: 'AzureFrontDoor.Backend'
          tag: 'ServiceTag'
          action: 'Allow'
          priority: 100
          name: 'AllowFrontdoor'
          headers: {
            'x-azure-fdid': [
              '${frontdoor.properties.frontdoorId}'
            ]
          }
        }
      ] : []
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
          value: sql.outputs.sqlFqdn
        }
        {
          name: 'DbName'
          value: sql.outputs.dbName
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
          name: 'AzureAd:Scopes'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-scope)'
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
          name: 'MemberServiceUri'
          value: 'https://${membersvcapp}.azurewebsites.net'
        }
        {
          name: 'OverrideAuthRedirectHostName'
          value: (enableAppGateway == 'true') ? 'https://demo.contoso.com/signin-oidc' : (enableFrontdoor == 'true') ? 'https://${frontdoorFqdn}/signin-oidc' : ''
        }
      ]
    }
  }
}

module memberportaldeploy './appdeploy.bicep' = {
  name: 'deployMemberPortal'
  params: {
    uri: '${storageAccountUri}-website-${appVersion}.zip?${sas}'
    parentName: memberportal
  }
}
// Member Portal website
var memberportal = '${stackName}mempapp'
resource mempappsite 'Microsoft.Web/sites@2021-01-15' = {
  name: memberportal
  location: location
  tags: tags
  identity: identity
  properties: {
    keyVaultReferenceIdentity: managedIdentityId
    serverFarmId: webappplan.id
    httpsOnly: true
    siteConfig: {
      http20Enabled: true
      minTlsVersion: '1.2'
      ipSecurityRestrictions: (enableAppGateway == 'true') ? [
        {
          vnetSubnetResourceId: subnetId
          action: 'Allow'
          tag: 'Default'
          priority: 200
          name: 'AllowAppGatewaySubnet'
        }
      ] : (enableFrontdoor == 'true') ? [
        {
          ipAddress: 'AzureFrontDoor.Backend'
          tag: 'ServiceTag'
          action: 'Allow'
          priority: 100
          name: 'AllowFrontdoor'
          headers: {
            'x-azure-fdid': [
              '${frontdoor.properties.frontdoorId}'
            ]
          }
        }
      ] : []
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
          value: sql.outputs.sqlFqdn
        }
        {
          name: 'DbName'
          value: sql.outputs.dbName
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
          name: 'AzureAd:Scopes'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-scope)'
        }
        {
          name: 'MemberPointsUrl'
          value: 'https://${pointsapi}.azurewebsites.net'
        }
        {
          name: 'OverrideAuthRedirectHostName'
          value: (enableAppGateway == 'true') ? 'https://demo.contoso.com/signin-oidc' : (enableFrontdoor == 'true') ? 'https://${frontdoorFqdn}/signin-oidc' : ''
        }
      ]
    }
  }
}

var apiapp = '${stackName}apiapp'
resource apiappplan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: apiapp
  location: location
  tags: tags
  sku: {
    name: appPlanName
  }
}

module altiddeploy './appdeploy.bicep' = {
  name: 'deployAlternateId'
  params: {
    uri: '${storageAccountUri}-alternate-id-service-${appVersion}.zip?${sas}'
    parentName: altidapp
  }
}

var altidapp = '${stackName}altidapp'
resource altidappsite 'Microsoft.Web/sites@2021-01-15' = {
  name: altidapp
  location: location
  tags: tags
  identity: identity
  properties: {
    keyVaultReferenceIdentity: managedIdentityId
    serverFarmId: apiappplan.id
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
          value: sql.outputs.sqlFqdn
        }
        {
          name: 'DbName'
          value: sql.outputs.dbName
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
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-app-client-id)'
        }
        {
          name: 'AzureAd:Audience'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-app-audience)'
        }
      ]
    }
  }
}

module membersvcdeploy './appdeploy.bicep' = {
  name: 'deployMemberService'
  params: {
    uri: '${storageAccountUri}-member-service-${appVersion}.zip?${sas}'
    parentName: membersvcapp
  }
}

var membersvcapp = '${stackName}membersvcapp'
resource membersvcappsite 'Microsoft.Web/sites@2021-01-15' = {
  name: membersvcapp
  location: location
  tags: tags
  identity: identity
  properties: {
    keyVaultReferenceIdentity: managedIdentityId
    serverFarmId: apiappplan.id
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
          value: sql.outputs.sqlFqdn
        }
        {
          name: 'DbName'
          value: sql.outputs.dbName
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
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-app-client-id)'
        }
        {
          name: 'AzureAd:Audience'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-app-audience)'
        }
        {
          name: 'AlternateIdServiceUri'
          value: 'https://${altidapp}.azurewebsites.net'
        }
      ]
    }
  }
}

module pointsdeploy './appdeploy.bicep' = {
  name: 'deployPoints'
  params: {
    uri: '${storageAccountUri}-member-points-service-${appVersion}.zip?${sas}'
    parentName: pointsapi
  }
}

var pointsapi = '${stackName}pointsapi'
resource pointsapisite 'Microsoft.Web/sites@2021-01-15' = {
  name: pointsapi
  location: location
  tags: tags
  identity: identity
  properties: {
    keyVaultReferenceIdentity: managedIdentityId
    serverFarmId: apiappplan.id
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
          value: sql.outputs.sqlFqdn
        }
        {
          name: 'DbName'
          value: sql.outputs.dbName
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
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-app-client-id)'
        }
        {
          name: 'AzureAd:Audience'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=contoso-customer-service-aad-app-audience)'
        }
      ]
    }
  }
}

var partapiapp = '${stackName}partapiapp'
resource partapiappsite 'Microsoft.Web/sites@2021-01-15' = {
  name: partapiapp
  location: location
  tags: tags
  identity: identity
  properties: {
    keyVaultReferenceIdentity: managedIdentityId
    serverFarmId: apiappplan.id
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
          value: sql.outputs.sqlFqdn
        }
        {
          name: 'DbName'
          value: sql.outputs.dbName
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

module backendstoragequeuedeploy './appdeploy.bicep' = {
  name: 'deployBackendStorageQueue'
  params: {
    uri: '${storageAccountUri}-storage-queue-func-${appVersion}.zip?${sas}'
    parentName: backendapp
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
          value: sql.outputs.sqlFqdn
        }
        {
          name: 'DbName'
          value: sql.outputs.dbName
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
output mem string = memberportal
output pointsapi string = pointsapi
output altid string = altidapp
output partapi string = partapiapp
output membersvc string = membersvcapp
output backend string = backendapp
output sqlserver string = sql.outputs.sqlFqdn
output sqlusername string = sqlUsername
output dbname string = sql.outputs.dbName

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

var csappsiteFqdn = '${csapp}.azurewebsites.net'
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
        name: 'port_https'
        properties: {
          port: 443
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
            id: '${appGwId}/frontendPorts/port_https'
          }
          protocol: 'Https'
          sslCertificate: {
            id: '${appGwId}/sslCertificates/appgwcert'
          }
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

var frontendEndpointName = '${stackName}-azurefd-net'
var backendPoolName = 'customer-service-backend-pool'
var frontdoorFqdn = '${stackName}.azurefd.net'

resource frontdoor 'Microsoft.Network/frontDoors@2020-05-01' = if (enableFrontdoor == 'true') {
  name: stackName
  location: 'global'
  tags: tags
  properties: {
    healthProbeSettings: [
      {
        name: 'hp'
        properties: {
          healthProbeMethod: 'GET'
          intervalInSeconds: 30
          path: '/health'
          protocol: 'Https'
        }
      }
    ]
    loadBalancingSettings: [
      {
        name: 'lb'
        properties: {
          sampleSize: 4
          successfulSamplesRequired: 2
          additionalLatencyMilliseconds: 0
        }
      }
    ]
    frontendEndpoints: [
      {
        name: frontendEndpointName
        properties: {
          hostName: frontdoorFqdn
        }
      }
    ]
    backendPools: [
      {
        name: backendPoolName
        properties: {
          backends: [
            {
              address: csappsiteFqdn
              httpsPort: 443
              httpPort: 80
              priority: 1
              weight: 50
              backendHostHeader: csappsiteFqdn
            }
          ]
          loadBalancingSettings: {
            id: resourceId('Microsoft.Network/frontDoors/loadBalancingSettings', stackName, 'lb')
          }
          healthProbeSettings: {
            id: resourceId('Microsoft.Network/frontDoors/healthProbeSettings', stackName, 'hp')
          }
        }
      }
    ]
    routingRules: [
      {
        name: 'contoso-customer-app-routing'
        properties: {
          frontendEndpoints: [
            {
              id: resourceId('Microsoft.Network/frontDoors/frontendEndpoints', stackName, frontendEndpointName)
            }
          ]
          acceptedProtocols: [
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            forwardingProtocol: 'HttpsOnly'
            backendPool: {
              id: resourceId('Microsoft.Network/frontDoors/backendPools', stackName, backendPoolName)
            }
          }
          enabledState: 'Enabled'
        }
      }
    ]
  }
}

resource apim 'Microsoft.ApiManagement/service@2021-01-01-preview' = if (enableAPIM == 'true') {
  name: stackName
  location: location
  tags: tags
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: 'api@contoso.com'
    publisherName: 'Contoso'
  }
}

resource rewardsapi 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' = if (enableAPIM == 'true') {
  parent: apim
  name: 'rewards-api'
  properties: {
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    apiRevision: '1'
    isCurrent: true
    displayName: 'Rewards API'
    path: 'rewards'
    protocols: [
      'https'
    ]
  }
}

resource rewardsapiMemberLookup 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = if (enableAPIM == 'true') {
  parent: rewardsapi
  name: 'rewards-member-lookup'
  properties: {
    templateParameters: [
      {
        name: 'memberId'
        description: 'Member Id'
        type: 'string'
        required: true
        values: []
      }
    ]
    description: 'Use this operation to lookup member information.'
    responses: [
      {
        statusCode: 200
        headers: []
        representations: []
      }
    ]
    displayName: 'Lookup member'
    method: 'GET'
    urlTemplate: '/member/{memberId}'
  }
}

var rawValue = replace(loadTextContent('member-lookup.xml'), '%MEMBERSVC%', membersvcapp)
resource rewardsapiMemberLookupPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2021-04-01-preview' = if (enableAPIM == 'true') {
  parent: rewardsapiMemberLookup
  name: 'policy'
  properties: {
    value: rawValue
    format: 'rawxml'
  }
}

resource apimlogger 'Microsoft.ApiManagement/service/loggers@2021-04-01-preview' = if (enableAPIM == 'true') {
  parent: apim
  name: stackName
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appinsights.properties.InstrumentationKey
    }
    resourceId: appinsights.id
  }
}
