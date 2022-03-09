param(
    [string]$BUILD_ENV,
    [string]$RESOURCE_GROUP)

$platformRes = (az resource list --tag stack-name=platform | ConvertFrom-Json)
if (!$platformRes) {
    throw "Unable to find eligible platform resource!"
}
if ($platformRes.Length -eq 0) {
    throw "Unable to find 'ANY' eligible platform resource!"
}
$kv = ($platformRes | Where-Object { $_.type -eq "Microsoft.KeyVault/vaults" -and $_.tags.'stack-environment' -eq 'prod' })
if (!$kv) {
    throw "Unable to find Key Vault resource!"
}

$kvName = $kv.name
Write-Host "::set-output name=keyVaultName::$kvName"

# Also resolve managed identity to use
$mid = (az identity list -g appservice-dev | ConvertFrom-Json).id
Write-Host "::set-output name=managedIdentityId::$mid"

$sqlPassword = (az keyvault secret show -n contoso-customer-service-sql-password --vault-name $kvName --query value | ConvertFrom-Json)
Write-Host "::set-output name=sqlPassword::$sqlPassword"

$config = ($platformRes | Where-Object { $_.type -eq "Microsoft.AppConfiguration/configurationStores" -and $_.tags.'stack-environment' -eq 'prod' })
if (!$config) {
    throw "Unable to find App Config resource!"
}

$configName = $config.name
$enableAppGateway = (az appconfig kv show -n $configName --key "contoso-customer-service/deployment-flags/enable-app-gateway" --label $BUILD_ENV --auth-mode login | ConvertFrom-Json).value
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to get enable-app-gateway flag from $configName."
}
Write-Host "::set-output name=enableAppGateway::$enableAppGateway"

$vnet = ($platformRes | Where-Object { $_.type -eq "Microsoft.Network/virtualNetworks" -and $_.name.Contains("-pri-") -and $_.tags.'stack-environment' -eq $BUILD_ENV })
if (!$vnet) {
    throw "Unable to find Virtual Network resource!"
}
$vnetRg = $vnet.resourceGroup
$vnetName = $vnet.name

$subnets = (az network vnet subnet list -g $vnetRg --vnet-name $vnetName | ConvertFrom-Json)
if (!$subnets) {
    throw "Unable to find eligible Subnets from Virtual Network $vnetName!"
}          
$subnetId = ($subnets | Where-Object { $_.name -eq "default" }).id
if (!$subnetId) {
    throw "Unable to find default Subnet resource!"
}

Write-Host "::set-output name=subnetId::$subnetId"