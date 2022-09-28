param(
    [Parameter(Mandatory = $true)][string]$ArdSolutionId)

$BUILD_ENV = "dev"
$groups = az group list --tag ard-environment=$BUILD_ENV | ConvertFrom-Json
$resourceGroupName = ($groups | Where-Object { $_.tags.'ard-solution-id' -eq $ArdSolutionId -and $_.tags.'ard-environment' -eq $BUILD_ENV }).name

$count = 0
$ardRes = (az resource list --tag ard-solution-id=$ArdSolutionId | ConvertFrom-Json)
$devRes = $ardRes | Where-Object { $_.tags.'ard-environment' -eq $BUILD_ENV }
if ($devRes -and $devRes.Length -gt 0) {
    $devRes | ForEach-Object {
        if ($_.resourceGroup -eq $resourceGroupName) {
            $id = $_.id
            Write-Host "Removing $id"
            az resource delete --id $_.id
            $count += 1
        }    
    }
}

Write-Host "Number of resource deleted: $count"