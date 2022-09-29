param(
    [Parameter(Mandatory = $true)][string]$ArdSolutionId,
    [Parameter(Mandatory = $false)][string]$BUILD_ENV)

$ErrorActionPreference = "Stop"
if (!$BUILD_ENV) {
    $BUILD_ENV = "dev"
}
$groups = az group list --tag ard-environment=$BUILD_ENV | ConvertFrom-Json
$resourceGroupName = ($groups | Where-Object { $_.tags.'ard-solution-id' -eq $ArdSolutionId -and $_.tags.'ard-environment' -eq $BUILD_ENV }).name

$count = 0
$ardRes = (az resource list --tag ard-solution-id=$ArdSolutionId | ConvertFrom-Json)
$devRes = $ardRes | Where-Object { $_.tags.'ard-environment' -eq $BUILD_ENV }
if ($devRes -and $devRes.Length -gt 0) {

    $locks = az lock list --resource-group $resourceGroupName | ConvertFrom-Json
    if ($locks.Length -eq 1) {
        az lock delete --name $locks.name --resource-group $locks.resourceGroup
        if ($LastExitCode -ne 0) {
            throw "An error has occured. Unable to delete lock."
        }
    }

    $devRes | ForEach-Object {
        if ($_.resourceGroup -eq $resourceGroupName) {
            $id = $_.id
            Write-Host "Removing $id"
            az resource delete --id $_.id
            $count += 1
        }    
    }

    if ($locks.Length -eq 1) {
        az lock create --name $locks.name --lock-type $locks.level --resource-group $locks.resourceGroup
        if ($LastExitCode -ne 0) {
            throw "An error has occured. Unable to re-add lock."
        }
    }
}

Write-Host "Number of resource deleted: $count"