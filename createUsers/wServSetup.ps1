# Define variables
$DomainName = "medicArgile.local"
$Company = "medicArgile"

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




