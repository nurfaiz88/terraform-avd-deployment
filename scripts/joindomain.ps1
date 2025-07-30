param (
    [string]$domainAdminUsername,
    [string]$domainAdminPassword
)

$domain = "nadiatraditionaltherapist.org"

# Secure the password
$password = ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ($domainAdminUsername, $password)

# Optional: Logging
Start-Transcript -Path "C:\joindomain.log" -Append

# Attempt to join domain
Add-Computer -DomainName $domain -Credential $creds -Restart

Stop-Transcript
