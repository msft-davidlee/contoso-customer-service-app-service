param(
    [string]$CustomerService, 
    [string]$AlternateId, 
    [string]$PartnerApi,
    [string]$Backend, 
    [string]$ResourceGroup, 
    [string]$BuildAccountName)

$ErrorActionPreference = "Stop"

az storage blob download-batch --destination . -s apps --account-name $BuildAccountName

az functionapp deployment source config-zip -g $ResourceGroup -n $CustomerService --src "contoso-demo-website-v1.zip"
az functionapp deployment source config-zip -g $ResourceGroup -n $AlternateId --src "contoso-demo-alternate-id-service-v1.zip"
az functionapp deployment source config-zip -g $ResourceGroup -n $PartnerApi --src "contoso-demo-partner-api-v1.zip"
az functionapp deployment source config-zip -g $ResourceGroup -n $Backend --src "contoso-demo-storage-queue-func-v1.zip"