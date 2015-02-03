<#

.SYNOPSIS
    Sets the Scratch location for each of the heads on the Infrastructure datastore.

.DESCRIPTION
    This script takes a series of vCenter Servers with credentials stored in a CSV file that
    is specified with the -CsvPath parameter.

    The CSV File should have the following format with one vCenter/ESXi Host per line

    vcenter,username,password
    eg-vc01.mydomain.com,myuser,mypassword

    Each vCenter is parsed sequentially and any errors will cause the script to stop processing. 
	It will create the scratch directory structure and apply the configuration to each host.
	A host reboot is required after this is applied. 

.PARAMETER CsvPath
    The full path to the CSV File containing the vCenter Servers and Credentials
	CSV Format: vcenter, username, password, datastore

.EXAMPLE
    ./Set-ESXiScratch.ps1 -CsvPath ./vcenterservers.csv

.NOTES
    Version:        1.0
    Author:         Steven Marks
    Creation Date:  03.02.2015
    Purpose/Change: Initial script development
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1)]
   [string]$CsvPath
)

$vCenter = ""

Try {
    # Load the PowerShell Modules for VMware PowerCLI if not already loaded (allows script to run via PowerShell as well as PowerCLI as long as PowerCLI is installed
    If ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null) { Add-PSSnapin VMware.VimAutomation.Core }

    # Import the vCenter Servers
    $csvData = Import-Csv $CsvPath

    $TotalvCenter = $csvData.Count
    $ProcessedvCenter = 0

    # Create an Array for 
    $csvData | Foreach-Object {
        # Set the working vCenter
        $vCenter = $_.vCenter
        $datastore = $_.datastore
        # Connect to the vCenter Server
        $viServer = Connect-VIServer -Server $_.vcenter -User $_.username -Password $_.password
        $Datastore = Get-Datastore | Where-Object {$_.Name -like "*$datastore*"}
        $MountPSDrive = New-PSDrive -Name "SetupScratchLocation" -Root \ -PSProvider VimDatastore -Datastore ($Datastore)
        Set-Location SetupScratchLocation:
        New-Item ".scratch" -ItemType directory
        cd ".scratch"

        $ESXiHosts = Get-VMHost
        $ESXiHosts | ForEach-Object{
            $hostname = $_.name
            New-Item $hostname -ItemType directory
            Get-VMHost $_.Name | Get-VMHostAdvancedConfiguration -Name "ScratchConfig.ConfiguredScratchLocation"
			# Set the scratch location
            Set-VMHostAdvancedConfiguration -Name "ScratchConfig.ConfiguredScratchLocation" -Value "/vmfs/volumes/" + $Datastore.Name + "/.scratch-" + $_.Name
        }
		write-host "NOTE: Host must be rebooted for this to take effect!!"
        # Disconnect from the vCenter Server without prompting
        Disconnect-VIServer -Server $_.vcenter -Confirm:$False
        $ProcessedvCenter++
    }
}
Catch
{
    Write-Host "Last vCenter: " $vCenter
    Write-Error -Message $_.Exception.Message
    exit 1
}
Finally
{
    # Any code that should complete after an exception occurs
}

