# Run script as Administrator
# See: https://docs.microsoft.com/en-us/azure/application-gateway/create-ssl-portal#create-a-self-signed-certificate

$ErrorActionPreference = "stop"

$certPath = "cert:\localmachine\my"

$cert = New-SelfSignedCertificate `
    -CertStoreLocation $certPath `
    -DnsName "demo.contoso.com"

$thumbprint = $cert.Thumbprint

Add-Type -AssemblyName 'System.Web'
$password = [System.Web.Security.Membership]::GeneratePassword(15, 0)

$exportPassword = ConvertTo-SecureString -String $password -Force -AsPlainText

Export-PfxCertificate `
    -Cert "$certPath\$thumbprint" `
    -FilePath appgwcert.pfx `
    -Password $exportPassword

Write-Host $password