param(
    [string]$CustomerService, 
    [string]$AlternateId, 
    [string]$PartnerApi,
    [string]$Backend, 
    [string]$ResourceGroup, 
    [string]$BuildAccountName,
    [string]$AppCode,
    [string]$DbName,
    [string]$SqlServer,
    [string]$SqlUsername,
    [string]$SqlPassword)

$ErrorActionPreference = "Stop"

az storage blob download-batch --destination . -s apps --account-name $BuildAccountName

az functionapp deployment source config-zip -g $ResourceGroup -n $CustomerService --src "contoso-demo-website-v1.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy customer service."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $AlternateId --src "contoso-demo-alternate-id-service-v1.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy alternate id."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $PartnerApi --src "contoso-demo-partner-api-v1.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy partner api."
}

az functionapp deployment source config-zip -g $ResourceGroup -n $Backend --src "contoso-demo-storage-queue-func-v1.zip"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy backend."
}

Invoke-Sqlcmd -InputFile "$AppCode\Db\Migrations.sql" -Database $DbName -Username $SqlUsername -Password $SqlPassword