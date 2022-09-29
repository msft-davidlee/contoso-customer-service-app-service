param(
    [string]$BUILD_ENV,
    [string]$ArdSolutionId)

$ErrorActionPreference = "Stop"
    
$kv = (az resource list --tag ard-resource-id=shared-key-vault | ConvertFrom-Json)
if (!$kv) {
    throw "Unable to find eligible shared key vault resource!"
}

$kvName = $kv.name
Write-Host "::set-output name=keyVaultName::$kvName"
$sharedResourceGroup = $kv.resourceGroup
Write-Host "::set-output name=sharedResourceGroup::$sharedResourceGroup"

# This is the rg where the application should be deployed
$groups = az group list --tag ard-environment=$BUILD_ENV | ConvertFrom-Json
$appResourceGroup = ($groups | Where-Object { $_.tags.'ard-solution-id' -eq $ArdSolutionId }).name
Write-Host "::set-output name=appResourceGroup::$appResourceGroup"

# https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/template-tutorial-use-key-vault
$keyVaultId = $kv.id
Write-Host "::set-output name=keyVaultId::$keyVaultId"

$sqlPassword = (az keyvault secret show -n contoso-customer-service-sql-password --vault-name $kvName --query value | ConvertFrom-Json)
Write-Host "::set-output name=sqlPassword::$sqlPassword"

# Also resolve managed identity to use
$mid = (az identity list -g $sharedResourceGroup | ConvertFrom-Json).id
Write-Host "::set-output name=managedIdentityId::$mid"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to get managed identity from shared rg."
}

$config = (az resource list --tag ard-resource-id=shared-app-configuration | ConvertFrom-Json)
if (!$config) {
    throw "Unable to find App Config resource!"
}

$configName = $config.name
$enableAppGateway = (az appconfig kv show -n $configName --key "$ArdSolutionId/deployment-flags/enable-app-gateway" --label $BUILD_ENV --auth-mode login | ConvertFrom-Json).value
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to get enable-app-gateway flag from $configName."
}
Write-Host "::set-output name=enableAppGateway::$enableAppGateway"

$enableFrontdoor = (az appconfig kv show -n $configName --key "$ArdSolutionId/deployment-flags/enable-frontdoor" --label $BUILD_ENV --auth-mode login | ConvertFrom-Json).value
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to get enable-frontdoor flag from $configName."
}
Write-Host "::set-output name=enableFrontdoor::$enableFrontdoor"

$enableAPIM = (az appconfig kv show -n $configName --key "$ArdSolutionId/deployment-flags/enable-apim" --label $BUILD_ENV --auth-mode login | ConvertFrom-Json).value
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to get enable-APIM flag from $configName."
}
Write-Host "::set-output name=enableAPIM::$enableAPIM"

# $platformRes = (az resource list --tag stack-name=platform | ConvertFrom-Json)
# if (!$platformRes) {
#     throw "Unable to find eligible networking resource!"
# }
# if ($platformRes.Length -eq 0) {
#     throw "Unable to find 'ANY' eligible networking resource!"
# }
# $vnet = ($platformRes | Where-Object { $_.type -eq "Microsoft.Network/virtualNetworks" -and $_.name.Contains("-pri-") -and $_.tags.'stack-environment' -eq $BUILD_ENV })
# if (!$vnet) {
#     throw "Unable to find Virtual Network resource!"
# }
# $vnetRg = $vnet.resourceGroup
# $vnetName = $vnet.name

# $subnets = (az network vnet subnet list -g $vnetRg --vnet-name $vnetName | ConvertFrom-Json)
# if (!$subnets) {
#     throw "Unable to find eligible Subnets from Virtual Network $vnetName!"
# }          
# $subnetId = ($subnets | Where-Object { $_.name -eq "appgw" }).id
# if (!$subnetId) {
#     throw "Unable to find default Subnet resource!"
# }

# Write-Host "::set-output name=subnetId::$subnetId"

$strs = (az resource list --tag ard-resource-id=shared-storage | ConvertFrom-Json)
if (!$strs) {
    throw "Unable to find eligible platform storage account!"
}
$BuildAccountName = $strs.name
Write-Host "::set-output name=buildAccountName::$BuildAccountName"
$buildAccountResourceId = $strs.id
Write-Host "::set-output name=buildAccountResourceId::$buildAccountResourceId"