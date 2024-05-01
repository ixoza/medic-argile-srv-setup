$ConfigFilePath = "config.psd1"

$runInit = Read-Host -Prompt "Do you want to run the initial setup? (y/N)"

if ($runInit -eq "y") {
    if (Test-Path -Path $ConfigFilePath) {
        # Import the configuration file
        $Config = Import-PowerShellDataFile -Path $ConfigFilePath
        $IPAddress = $Config.IPAddress
        $SubnetMask = $Config.SubnetMask
        $GW = $Config.GW
        $DNS = $Config.DNS
        $HostName = $Config.HostName
        $DomainName = $Config.DomainName
        $DomainAdminPassword = $Config.DomainAdminPassword
        $DHCPScope = $Config.DHCPScope
        $DHCPStartRange = $Config.DHCPStartRange
        $DHCPEndRange = $Config.DHCPEndRange
        $DHCPRouter = $Config.DHCPRouter
        $DHCPDnsServerIP = $Config.DHCPDnsServerIP
    }
    else {
        Write-Error "Configuration file not found: $ConfigFilePath"
        break
    }
    
    # Validate the IP addresses
    $IPAddresses = @($IPAddress, $SubnetMask, $GW, $DNS, $DHCPScope, $DHCPStartRange, $DHCPEndRange, $DHCPRouter, $DHCPDnsServerIP)
    foreach ($address in $IPAddresses) {
        if (-not ([System.Net.IPAddress]::TryParse($address, [ref]0))) {
            Write-Error "Invalid IP address: $address"
            return
        }
    }
    
    # Validate the hostname
    if ($HostName -match "[^a-zA-Z0-9-.]") {
        Write-Error "Invalid hostname: $HostName"
        return
    }

    # Get the existing IP address
    $existingIP = Get-NetIPAddress -InterfaceAlias "Ethernet 2" -ErrorAction SilentlyContinue

    # If an IP address exists, remove it
    if ($null -ne $existingIP) {
        Remove-NetIPAddress -InterfaceAlias "Ethernet 2" -IPAddress $existingIP.IPAddress -Confirm:$false
    }
    
    # Set the IP address, subnet mask, and default gateway
    New-NetIPAddress -InterfaceAlias "Ethernet 2" -IPAddress $IPAddress -PrefixLength $SubnetMask -DefaultGateway $GW
    
    # Set the DNS servers
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses $DNS
    
    Read-Host "Press Enter to restart..."
    Write-Output "Restarting in 5 seconds..."
    Start-Sleep -Seconds 5
    Rename-Computer -NewName $HostName -Restart
}
elseif ($runInit -eq "n") {
    Write-Output "Skipping initial setup..."
}

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
$DHCPServerName = "$HostName.$DomainName"

if ($DhcpServers.DnsName -contains $DHCPServerName) {
    Write-Output "DHCP server $DHCPServerName is already authorized in Active Directory."
} else {
    Write-Output "DHCP server $DHCPServerName is not authorized in Active Directory."
    Add-DhcpServerInDC -DnsName "$HostName.$DomainName" -IPAddress 192.168.1.2
}

Import-Module ServerManager

# Check if WDS is already installed
if ((Get-WindowsFeature -Name 'WDS').InstallState -eq 'Installed') {
    Write-Host "WDS is already installed."
} else {
    # Install WDS
    Add-WindowsFeature -Name 'WDS' -IncludeManagementTools

    # Check if the installation was successful
    if ((Get-WindowsFeature -Name 'WDS').InstallState -eq 'Installed') {
        Write-Host "WDS installed successfully."
    } else {
        Write-Host "Failed to install WDS."
    }
}