<#
.SYNOPSIS

Removes the Primary User from an Intune-managed device using its machine name.

.DESCRIPTION

This script connects to Microsoft Graph and removes the Primary User associated with a specified Intune device.
It identifies the device by its machine name, retrieves the current user association, and performs a DELETE operation via Graph API.
Designed for automation workflows, device cleanup, and user reassignment scenarios.

.AUTHOR

Sujin Nelladath — Microsoft Graph MVP

.PARAMETER MachineName

Mandatory. The name of the device from which the Primary User should be removed.

.EXAMPLE
Remove Primary User from a device named 'HR-Laptop-01':
.\Remove-IntunePrimaryUser.ps1 -MachineName "HR-Laptop-01"

.NOTES
Requires Microsoft.Graph modules and the DeviceManagementManagedDevices.ReadWrite.All permission scope.
Uses the beta endpoint for user removal via `$ref`.

#>




param
(
    [Parameter(Mandatory = $true)]
    [string]$MachineName
)

# Check if Microsoft Graph module is installed

if (!(Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Error "Microsoft Graph module not installed. Run: Install-Module Microsoft.Graph"
    exit 1
}

# Import modules

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.DeviceManagement

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All"

# Find the device by name using Graph API

Write-Host "Looking for device: $MachineName"
$Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$filter=deviceName"
$Response = Invoke-MgGraphRequest -Method GET -Uri $Uri

$devicename = foreach ( $device in $Response.value)

{
   $device | Where-Object {$_.deviceName -eq $MachineName}
}

$deviceId = $devicename.id

if (!$devicename)
 {
    Write-Error "Device '$MachineName' not found in Intune"
    exit 1
}

Write-Host "Found device: $($devicename.deviceName) (ID: $($deviceId))"

# Get current primary users using Graph API

$UsersUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices('$($deviceId)')/users"
$UsersResponse = Invoke-MgGraphRequest -Method GET -Uri $UsersUri
$PrimaryUsers = $UsersResponse.value

if ($PrimaryUsers.Count -eq 0) 

{
    Write-Host "No primary users found for this device"
}

else 

{
    Write-Host "Found $($PrimaryUsers.Count) user associated with device"
    Write-Host ""$PrimaryUsers.displayName" is the primary using, the script will remove the user from the device" -ForegroundColor Yellow
    
    # Remove all user associations (there should only be one primary user max)

    try
    
    {
        # Remove primary user using simple DELETE to users/$ref endpoint
        $RemoveUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($deviceId)/users/`$ref"
        Invoke-MgGraphRequest -Method DELETE -Uri $RemoveUri
        
        Write-Host "Successfully removed primary user from device" -ForegroundColor Green
    }

    catch 
    {
        Write-Error "Failed to remove primary user: $($_.Exception.Message)" 
    }
}

Write-Host "Disconnecting from Microsoft Graph..."
Disconnect-MgGraph

Write-Host "Script completed."
