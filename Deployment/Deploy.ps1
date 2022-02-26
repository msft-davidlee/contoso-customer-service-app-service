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
$platformRes = (az resource list --tag stack-name=platform --tag stack-environment=prod | ConvertFrom-Json)
if (!$platformRes) {
    throw "Unable to find eligible platform resources!"
}
if ($platformRes.Length -eq 0) {
    throw "Unable to find 'ANY' eligible platform resources!"
}

$strs = ($platformRes | Where-Object { $_.type -eq "Microsoft.Storage/storageAccounts" })
if (!$strs) {
    throw "Unable to find eligible platform storage account!"
}
$BuildAccountName = $strs.name

az storage blob download-batch --destination . -s apps --account-name $BuildAccountName

$version = "v3.1"
az functionapp deployment source config-zip -g $ResourceGroup -n $CustomerService --src "contoso-demo-website-$version.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy customer service."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $AlternateId --src "contoso-demo-alternate-id-service-$version.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy alternate id."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $PartnerApi --src "contoso-demo-partner-api-$version.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy partner api."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $Backend --src "contoso-demo-storage-queue-func-$version.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy backend."
}

Invoke-Sqlcmd -InputFile "$AppCode\Db\Migrations.sql" -ServerInstance $SqlServer -Database $DbName -Username $SqlUsername -Password $SqlPassword