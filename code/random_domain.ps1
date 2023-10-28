# Define a parameter for the script, specifying the output JSON file path
param( [Parameter(Mandatory=$true)] $OutputJSONFile )

# Read the content of the text files containing group names, first names, last names, and passwords
$group_names = Get-Content "data/group_names.txt"
$first_names = Get-Content "data/first_names.txt"
$last_names = Get-Content "data/last_names.txt"
$passwords = Get-Content "data/passwords.txt"

# Initialize empty arrays to store groups and users
$groups = @()
$users = @()

# Set the number of groups to create
$num_groups = 10

# Generate random groups and add them to the groups array
for ($i = 0; $i -lt $num_groups; $i++) {
    # Get a random group name from the available group names
    $group_name = (Get-Random -InputObject $group_names)
    
    # Create a hashtable representing the group with the chosen name
    $group = @{ "name" = "$group_name" }
    
    # Add the group hashtable to the groups array
    $groups += $group
    
    # Remove the chosen group name from the available group names to avoid duplicates
    $group_names = $group_names | Where-Object { $_ -ne $group_name }
} 

# Set the number of users to create
$num_users = 100

# Generate random users and add them to the users array
for ($i = 0; $i -lt $num_users; $i++) {
    # Get a random first name, last name, and password from the available lists
    $first_name = (Get-Random -InputObject $first_names)
    $last_name = (Get-Random -InputObject $last_names)
    $password = (Get-Random -InputObject $passwords)

    # Create a hashtable representing the user with the chosen attributes
    $new_user = @{
        "name" = "$first_name $last_name"
        "password" = "$password"
        "groups" = @((Get-Random -InputObject $groups).name)
    }
    
    # Add the user hashtable to the users array
    $users += $new_user
    
    # Remove the chosen first name, last name, and password from the available lists to avoid duplicates
    $first_names = $first_names | Where-Object { $_ -ne $first_name }
    $last_names = $last_names | Where-Object { $_ -ne $last_name }
    $passwords = $passwords | Where-Object { $_ -ne $password }
}

# Convert the generated groups and users data to a JSON object and save it to the output file
ConvertTo-Json -InputObject @{
    "domain" = "xyz.com"
    "groups" = $groups
    "users" = $users
} | Out-File $OutputJSONFile