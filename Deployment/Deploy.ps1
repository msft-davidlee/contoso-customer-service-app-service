param(
    [string]$CustomerService, 
    [string]$AlternateId, 
    [string]$PartnerApi,
    [string]$MemberServiceApi,
    [string]$Backend, 
    [string]$ResourceGroup,
    [string]$BUILD_ENV,         
    [string]$DbName,
    [string]$SqlServer,
    [string]$SqlUsername,
    [string]$SqlPassword)

$ErrorActionPreference = "Stop"

# Shared components are tagged with the stack name of Platform for the environment.
$platformRes = (az resource list --tag stack-name=shared-storage | ConvertFrom-Json)
if (!$platformRes) {
    throw "Unable to find eligible platform resources!"
}
if ($platformRes.Length -eq 0) {
    throw "Unable to find 'ANY' eligible platform resources!"
}

$strs = ($platformRes | Where-Object { $_.tags.'stack-environment' -eq 'prod' })
if (!$strs) {
    throw "Unable to find eligible platform storage account!"
}

$BuildAccountName = $strs.name

# The version here can be configurable so we can also pull dev specific packages.
$version = "v4.4"

az storage blob download-batch --destination . -s apps --account-name $BuildAccountName --pattern *$version*.zip
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to download files."
}

$namePrefix = "contoso-demo"

az functionapp deployment source config-zip -g $ResourceGroup -n $CustomerService --src "$namePrefix-website-$version.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy customer service."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $AlternateId --src "$namePrefix-alternate-id-service-$version.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy alternate id."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $MemberServiceApi --src "$namePrefix-member-service-$version.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy alternate id."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $PartnerApi --src "$namePrefix-partner-api-$version.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy partner api."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $Backend --src "$namePrefix-storage-queue-func-$version.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy backend."
}

# Deploy specfic version of SQL script
$sqlFile = "Migrations-$version.sql"
az storage blob download-batch --destination . -s apps --account-name $BuildAccountName --pattern $sqlFile
Invoke-Sqlcmd -InputFile $sqlFile -ServerInstance $SqlServer -Database $DbName -Username $SqlUsername -Password $SqlPassword