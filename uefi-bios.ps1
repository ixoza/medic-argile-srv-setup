#   TAKEN FROM: https://www.it-connect.fr/serveurs-dhcp-wds-boot-pxe-bios-et-uefi/
#   Credits : Florian BURNEL
$Config = Import-PowerShellDataFile -Path "config.psd1"

$HostName = $Config.HostName

# Nom d'hôte du serveur DHCP
$DhcpServerName = "$HostName"

Write-Output "$DhcpServerName"

# Adresse IP du serveur WDS (PXE)
$PxeServerIp = "192.168.1.2"
# Adresse reseau de l'étendue DHCP ciblée
$Scope = "192.168.1.0"

Add-DhcpServerv4Class -ComputerName $DhcpServerName -Name "PXEClient - UEFI x64" -Type Vendor -Data "PXEClient:Arch:00007" -Description "PXEClient:Arch:00007"
Add-DhcpServerv4Class -ComputerName $DhcpServerName -Name "PXEClient - UEFI x86" -Type Vendor -Data "PXEClient:Arch:00006" -Description "PXEClient:Arch:00006"
Add-DhcpServerv4Class -ComputerName $DhcpServerName -Name "PXEClient - BIOS x86 et x64" -Type Vendor -Data "PXEClient:Arch:00000" -Description "PXEClient:Arch:00000"

$PolicyNameBIOS = "PXEClient - BIOS x86 et x64"
Add-DhcpServerv4Policy -Computername $DhcpServerName -ScopeId $Scope -Name $PolicyNameBIOS -Description "Options DHCP pour boot BIOS x86 et x64" -Condition Or -VendorClass EQ, "PXEClient - BIOS x86 et x64*"
Set-DhcpServerv4OptionValue -ComputerName $DhcpServerName -ScopeId $Scope -OptionId 066 -Value $PxeServerIp -PolicyName $PolicyNameBIOS
Set-DhcpServerv4OptionValue -ComputerName $DhcpServerName -ScopeId $Scope -OptionId 067 -Value boot\x64\wdsnbp.com -PolicyName $PolicyNameBIOS

$PolicyNameUEFIx86 = "PXEClient - UEFI x86"
Add-DhcpServerv4Policy -Computername $DhcpServerName -ScopeId $Scope -Name $PolicyNameUEFIx86 -Description "Options DHCP pour boot UEFI x86" -Condition Or -VendorClass EQ, "PXEClient - UEFI x86*"
Set-DhcpServerv4OptionValue -ComputerName $DhcpServerName -ScopeId $Scope -OptionId 060 -Value PXEClient -PolicyName $PolicyNameUEFIx86
Set-DhcpServerv4OptionValue -ComputerName $DhcpServerName -ScopeId $Scope -OptionId 066 -Value $PxeServerIp -PolicyName $PolicyNameUEFIx86
Set-DhcpServerv4OptionValue -ComputerName $DhcpServerName -ScopeId $Scope -OptionId 067 -Value boot\x86\wdsmgfw.efi -PolicyName $PolicyNameUEFIx86

$PolicyNameUEFIx64 = "PXEClient - UEFI x64"
Add-DhcpServerv4Policy -Computername $DhcpServerName -ScopeId $Scope -Name $PolicyNameUEFIx64 -Description "Options DHCP pour boot UEFI x64" -Condition Or -VendorClass EQ, "PXEClient - UEFI x64*"
Set-DhcpServerv4OptionValue -ComputerName $DhcpServerName -ScopeId $Scope -OptionId 060 -Value PXEClient -PolicyName $PolicyNameUEFIx64
Set-DhcpServerv4OptionValue -ComputerName $DhcpServerName -ScopeId $Scope -OptionId 066 -Value $PxeServerIp -PolicyName $PolicyNameUEFIx64
Set-DhcpServerv4OptionValue -ComputerName $DhcpServerName -ScopeId $Scope -OptionId 067 -Value boot\x64\wdsmgfw.efi -PolicyName $PolicyNameUEFIx64