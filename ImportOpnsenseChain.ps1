<#
  .SYNOPSIS
  Tobias, 24-3-2024.
  This script is based on 2 articles I have read about downloading ACME certificates via the Pfsense webUI, now modified for Opnsense.
  .DESCRIPTION
  This script downloads ACME certificates from Opnsense and imports them into MS certificate manager with the CA certificate inside
  .EXAMPLE
  PS> .\importOpnsenseCertChain.ps1
  Scheduled task: powershell.exe -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -File .\importOpnsenseCertChain.ps1
  .LINK
  Webrequests to OpnSense based on:
  https://www.chadmccune.net/2020/07/30/scripting-pfsense-dhcp-static-assignments/
  https://forum.netgate.com/topic/123405/get-certificates-from-pfsense-cert-manager-using-linux-commandline/4
  https://github.com/TobiasS1402/opnsense-acme-utils
#>

$OpnSenseUsername = "CertMgmt" #Username of your restricted useraccount
$OpnSensePassword = "Password" #Password of your restricted useraccount
$OpnSenseUrl = "https://fqdn.opnsense.local" #FQDN or IP address of your OpnSense instance
$CertificateId = "" #OpnSense certificate id to download
$CertificateAuthorityId = "" #OpnSense CA certificate id to download
$CertificateName = "" #Name to give to the downloaded files
$CertificateDirectory = "c:\windows\temp" #Location on your Windows instance where the certificates will be downloaded
$PfxPassword = "" #password to generate and import the pfx file with certutil

try {
    try {
        if ((Test-Path -Path $CertificateDirectory -ErrorAction Stop) -eq $false){
            New-Item -ItemType Directory -Path $CertificateDirectory
        }
        else {
        }
    }
    catch {
        New-Item -ItemType Directory -Path $CertificateDirectory
    }

    #Request to get the CSRF token for this session
    $LastRequest = (Invoke-WebRequest "$OpnSenseUrl/system_certmanager.php" -SessionVariable OpnSenseSession -UseBasicParsing)
    
    #Request to authenticate
    $PostParams = @{$LastRequest.InputFields[0].name=$LastRequest.InputFields[0].value;usernamefld=$OpnSenseUsername;passwordfld=$OpnSensePassword;login=1}
    $LastRequest = (Invoke-WebRequest "$OpnSenseUrl/system_certmanager.php" -WebSession $OpnSenseSession -Method Post -Body $PostParams -UseBasicParsing)

    #Request to download the certificate
    (Invoke-WebRequest "$OpnSenseUrl/system_certmanager.php?act=exp&id=$CertificateId" -OutFile "$CertificateDirectory\$CertificateName.crt" -WebSession $OpnSenseSession -Method Get -UseBasicParsing)

    #Request to download the CA certificate
    (Invoke-WebRequest "$OpnSenseUrl/system_camanager.php?act=exp&id=$CertificateAuthorityId" -OutFile "$CertificateDirectory\$CertificateName.ca" -WebSession $OpnSenseSession -Method Get -UseBasicParsing)

    #Request to download the private key
    (Invoke-WebRequest "$OpnSenseUrl/system_certmanager.php?act=key&id=$CertificateId" -OutFile "$CertificateDirectory\$CertificateName.key" -WebSession $OpnSenseSession -Method Get -UseBasicParsing)
}
catch {
    #TLS config as system / service acount
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

#merge pfx and import the certificate into the personal LocalMachine store
Get-Content $CertificateDirectory\$CertificateName.ca >> $CertificateDirectory\$CertificateName.crt #merge cert with ca cert
certutil.exe -p "$PfxPassword,$PfxPassword" -f -MergePFX $CertificateDirectory\$CertificateName.crt $CertificateDirectory\$CertificateName.pfx #Merge the PFX itself
$ThumbPrint = Import-pfxCertificate -FilePath "$CertificateDirectory\$CertificateName.pfx" -password (ConvertTo-SecureString $PfxPassword -AsPlainText -Force) -CertStoreLocation Cert:\LocalMachine\My | Select-Object -ExpandProperty Thumbprint #select thumbprint

Write-Host $ThumbPrint

#Cleanup actions for the certificates
Remove-Item  -Exclude "$CertificateName.pfx" -Path $CertificateDirectory\$CertificateName.crt -Force
Remove-Item  -Exclude "$CertificateName.pfx" -Path $CertificateDirectory\$CertificateName.key -Force
Remove-Item  -Exclude "$CertificateName.pfx" -Path $CertificateDirectory\$CertificateName.ca -Force
