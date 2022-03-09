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

$enableAppGateway = az appconfig kv show -n $config.name --key "contoso-customer-service/deployment-flags/enable-app-gateway" --label $BUILD_ENV
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to get enable-app-gateway flag."
}
Write-Host "::set-output name=enableappgateway::$enableAppGateway"