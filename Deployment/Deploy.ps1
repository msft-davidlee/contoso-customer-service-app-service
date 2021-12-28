param(
    [string]$CustomerService, 
    [string]$AlternateId, 
    [string]$PartnerApi,
    [string]$Backend, 
    [string]$ResourceGroup,
    [string]$BUILD_ENV,     
    [string]$AppCode,
    [string]$DbName,
    [string]$SqlServer,
    [string]$SqlUsername,
    [string]$SqlPassword)

$ErrorActionPreference = "Stop"

# Shared components are tagged with the stack name of Platform for the environment.
$platformRes = (az resource list --tag stack-name="platform" | ConvertFrom-Json)
if (!$platformRes) {
    throw "Unable to find eligible platform resources!"
}
if ($platformRes.Length -eq 0) {
    throw "Unable to find 'ANY' eligible platform resources!"
}

$strs = ($platformRes | Where-Object { $_.type -eq "Microsoft.Storage/storageAccounts" -and $_.resourceGroup.EndsWith("-$BUILD_ENV") })
if (!$strs) {
    throw "Unable to find eligible platform storage account!"
}
$BuildAccountName = $strs.name

az storage blob download-batch --destination . -s apps --account-name $BuildAccountName

az functionapp deployment source config-zip -g $ResourceGroup -n $CustomerService --src "contoso-demo-website-v3.0.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy customer service."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $AlternateId --src "contoso-demo-alternate-id-service-v3.0.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy alternate id."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $PartnerApi --src "contoso-demo-partner-api-v3.0.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy partner api."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $Backend --src "contoso-demo-storage-queue-func-v3.0.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy backend."
}

Invoke-Sqlcmd -InputFile "$AppCode\Db\Migrations.sql" -ServerInstance $SqlServer -Database $DbName -Username $SqlUsername -Password $SqlPassword