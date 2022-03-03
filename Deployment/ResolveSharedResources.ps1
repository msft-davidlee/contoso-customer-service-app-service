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