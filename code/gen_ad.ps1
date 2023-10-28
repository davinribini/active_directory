# Define parameters for the script, specifying the JSON file and an optional "Undo" switch
param(
    [Parameter(Mandatory=$true)] $JSONFile,
    [switch]$Undo
)

# Define a function to create an Active Directory group
function CreateADGroup(){
    param( [Parameter(Mandatory=$true)] $groupObject )
    
    # Extract the group name from the JSON object
    $name = $groupObject.name
    
    # Create a new Active Directory group with the given name and Global scope
    New-ADGroup -name $name -GroupScope Global
} 

# Define a function to remove an Active Directory group
function RemoveADGroup(){
    param( [Parameter(Mandatory=$true)] $groupObject )
    
    # Extract the group name from the JSON object
    $name = $groupObject.name
    
    # Remove the Active Directory group with the specified name
    Remove-ADGroup -Identity $name -Confirm:$false
}

# Define a function to create an Active Directory user
function CreateADUser(){
    param( [Parameter(Mandatory=$true)] $userObject )
    
    # Pull out the name and password from the JSON object
    $name = $userObject.name
    $password = $userObject.password

    # Generate a username in the format "first initial + last name" and set other attributes
    $firstname, $lastname = $name.Split(" ")
    $username = ($firstname[0] + $lastname).ToLower()
    $samAccountName = $username
    $principalname = $username

    # Create the AD user object with the provided attributes and enable the account
    New-ADUser -Name "$name" -GivenName $firstname -Surname $lastname -SamAccountName $SamAccountName -UserPrincipalName $principalname@$Global:Domain -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) -PassThru | Enable-ADAccount

    # Add the user to the appropriate group(s) specified in the JSON object
    foreach($group_name in $userObject.groups) {
        try {
            Get-ADGroup -Identity "$group_name"
            Add-ADGroupMember -Identity $group_name -Members $username
        } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            Write-Warning "User $name NOT added to group $group_name because it does not exist"
        }
    }
}

# Define a function to remove an Active Directory user
function RemoveADUser(){
    param( [Parameter(Mandatory=$true)] $userObject )
    
    # Extract the user's full name from the JSON object
    $name = $userObject.name
    $firstname, $lastname = $name.Split(" ")
    $username = ($firstname[0] + $lastname).ToLower()
    $samAccountName = $username
    
    # Remove the Active Directory user with the specified username
    Remove-ADUser -Identity $samAccountname -Confirm:$false
}

# Define a function to weaken the password policy in the local security policy
function WeakenPasswordPolicy(){
    # Export the current security policy to a temporary file
    secedit /export /cfg C:\Windows\Tasks\secpol.cfg
    
    # Modify the exported security policy to set weaker password complexity and minimum length
    (Get-Content C:\Windows\Tasks\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0").replace("MinimumPasswordLength = 7", "MinimumPasswordLength = 1").replace("MinimumPasswordLength = 7", "MinimumPasswordLength = 1") | Out-File C:\Windows\Tasks\secpol.cfg
    
    # Apply the modified security policy to the system
    secedit /configure /db c:\windows\security\local.sdb /cfg C:\Windows\Tasks\secpol.cfg /areas SECURITYPOLICY
    
    # Clean up the temporary file
    rm -force C:\Windows\Tasks\secpol.cfg -confirm:$false
}

# Define a function to strengthen the password policy in the local security policy
function StrengthenPasswordPolicy(){
    # Export the current security policy to a temporary file
    secedit /export /cfg C:\Windows\Tasks\secpol.cfg
    
    # Modify the exported security policy to set stronger password complexity and minimum length
    (Get-Content C:\Windows\Tasks\secpol.cfg).replace("PasswordComplexity = 0", "PasswordComplexity = 1").replace("MinimumPasswordLength = 1", "MinimumPasswordLength = 7").replace("MinimumPasswordLength = 7", "MinimumPasswordLength = 1") | Out-File C:\Windows\Tasks\secpol.cfg
    
    # Apply the modified security policy to the system
    secedit /configure /db c:\windows\security\local.sdb /cfg C:\Windows\Tasks\secpol.cfg /areas SECURITYPOLICY
    
    # Clean up the temporary file
    rm -force C:\Windows\Tasks\secpol.cfg -confirm:$false
}

# Read the JSON data from the specified file and set the global domain variable
$json = (Get-Content $JSONFile | ConvertFrom-JSON)
$Global:Domain = $json.domain

# Check if the script is running in "Undo" mode or not
if (-not $Undo) {
    # If not in "Undo" mode, weaken the password policy first
    WeakenPasswordPolicy

    # Create Active Directory groups based on the data in the JSON file
    foreach ($group in $json.groups) {
        CreateADGroup $group
    }
    
    # Create Active Directory users and add them to the appropriate groups based on the data in the JSON file
    foreach ($user in $json.users) {
        CreateADUser $user
    }
} else {
    # If in "Undo" mode, strengthen the password policy first
    StrengthenPasswordPolicy

    # Remove Active Directory users based on the data in the JSON file
    foreach ($user in $json.users) {
        RemoveADUser $user
    }
    
    # Remove Active Directory groups based on the data in the JSON file
    foreach ($group in $json.groups) {
        RemoveADGroup $group
    }
}