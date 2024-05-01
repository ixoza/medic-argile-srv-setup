# Define variables
$DomainName = "medicArgile.local"
$Company = "medicArgile"
$DomainAdminPassword = "Admin19"
$DHCPScope = "192.168.1.0"
$DHCPStartRange = "192.168.1.100"
$DHCPEndRange = "192.168.1.200"
$DHCPRouter = "192.168.1.254"
$DNSServerIP = "192.168.1.2" # Use the server's IP if DNS is installed locally

# Install DNS Server
Install-WindowsFeature -Name DNS -IncludeManagementTools

# Install DHCP Server
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Install ADDS (Active Directory Domain Services)
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

try {
    $null = Get-ADForest -Server $DomainName
    Write-Output "AD DS forest $DomainName already exists."
} catch {
    Write-Output "AD DS forest $DomainName does not exist. Creating now..."
    Install-ADDSForest -DomainName $DomainName -SafeModeAdministratorPassword (ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force) -Force:$true
}

try {
    # Attempt to get the DHCP scope
    $null = Get-DhcpServerv4Scope -ScopeId $DHCPScope
    Write-Output "DHCP scope $ScopeId already exists."
} catch {
    Write-Output "DHCP scope $ScopeId does not exist. Creating now..."
    # Configure DHCP Server
    Add-DhcpServerv4Scope -Name $DHCPScope -StartRange $DHCPStartRange -EndRange $DHCPEndRange -SubnetMask "255.255.255.0" -State Active
    Set-DhcpServerv4OptionValue -ScopeId $DHCPScope -OptionId 3 -Value $DHCPRouter
    Set-DhcpServerv4OptionValue -ScopeId $DHCPScope -OptionId 6 -Value $DNSServerIP
    Set-DhcpServerv4OptionValue -ScopeId $DHCPScope -OptionId 15 -Value $DomainName
}

Start-Service -Name DHCPServer

$DhcpServers = Get-DhcpServerInDC
$DHCPServerName = "WIN-R85F2KVDQEI.medicArgile.local"

if ($DhcpServers.DnsName -contains $DHCPServerName) {
    Write-Output "DHCP server $DHCPServerName is already authorized in Active Directory."
} else {
    Write-Output "DHCP server $DHCPServerName is not authorized in Active Directory."
    Add-DhcpServerInDC -DnsName "WIN-R85F2KVDQEI.medicArgile.local" -IPAddress 192.168.1.2
}

$Departments = @(
    "Direction",
    "Commercial",
    "Technique",
    "Medical",
    "Production",
    "R&D",
    "Administratif"
)

$existingCompanyOU = Get-ADOrganizationalUnit -Filter "Name -like '$Company'"
if ($null -eq $existingCompanyOU) {
    # If the company OU does not exist, create it
    New-ADOrganizationalUnit -Name $Company
    Write-Host "OU '$Company' created successfully."
} else {
    Write-Host "OU '$Company' already exists."
}

# Create OUs for each department
foreach ($Department in $Departments) {
    # If the OU exists, this will not throw an error
    $existingOU = Get-ADOrganizationalUnit -Filter "Name -like '$Department'" -SearchBase ("OU=" + $Company + ",DC=medicArgile,DC=local")
    
    if ($null -eq $existingOU) {
        # If the OU does not exist, create it under the company OU
        New-ADOrganizationalUnit -Name $Department -Path ("OU=" + $Company + ",DC=medicArgile,DC=local")
        Write-Host "OU '$Department' created successfully under '$Company'."
    } else {
        Write-Host "OU '$Department' already exists under '$Company'."
    }
}

# Load JSON file containing user data
$UserData = Get-Content -Path "./users.json" | ConvertFrom-Json

# Loop through each user in the JSON data
foreach ($User in $UserData.Users) {
    # Extract user information
    $UserName = $User.UserName
    $FirstName = $User.FirstName
    $LastName = $User.LastName
    $Password = $User.Password
    $EmailAddress = $User.EmailAddress
    $OU = $User.OU # Organizational Unit where user will be created
    $SamUserName = $UserName.Substring(0, [Math]::Min(20, $UserName.Length)).TrimEnd()
    
    # Check if user already exists
    if ($null -eq (Get-ADUser -Filter {SamAccountName -eq $SamUserName})) {
        # Create user account
        New-ADUser -SamAccountName $SamUserName -UserPrincipalName "$UserName@$DomainName" -Name "$FirstName $LastName" -GivenName $FirstName -Surname $LastName -EmailAddress $EmailAddress -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) -Enabled $true -Path $OU -ChangePasswordAtLogon $true

        if ($null -ne (Get-ADUser -Filter {SamAccountName -eq $SamUserName})) {
            Write-Host "User account $UserName created successfully."
        } else {
            Write-Host "(!!!) Failed to create user account $UserName."
        }
    } else {
        Write-Host "User account $UserName already exists."
    }
}