###############################################
# Script connects to vcenter server and provides a csv report of portgroup VLAN's without VM's. 
# Paramterers: 
# -consoleonly : Output to console
# -VCServer : vcenter server to connect to
# -ReportExport : path of output File
# -vCenteruser : username for vcenterserver
# -vCenterpass : password for vcenterserver
#
###############################################


## script paramters
param(
    [parameter(Mandatory = $false)]
    [switch]$ConsoleOnly,
    [parameter(Mandatory = $false)]
    [String]$VCServer,
    [parameter(Mandatory = $false)]
    [string]$ReportExport,
	[parameter(Mandatory = $false)]
    [string]$vCenteruser,
	[parameter(Mandatory = $false)]
    [string]$vCenterpass
   )

  
   
if (!$ReportExport){
	$ReportExport = ".\"
}

if (!$VCServer){
	$VCServer = Read-host -Prompt 'Please input FQDN or IP of vsphere server'
}
if (!$vCenteruser){
	$vCenteruser = Read-host -Prompt 'Please input vSphere username. To use logged in user, leave empty'
}
if (!$vCenterpass){
	$vCenterpass = Read-host -Prompt 'Please input vSphere password'
}
## VCenter Connection
$connectedserver = $global:defaultviserver
if ($connectedserver)
{
	Write-output "Disconnecting from already connected vCenter $global:defaultviserver.`r`n"
	Disconnect-VIServer -Server $connectedserver -Confirm:$False	
	$connectedserver = $null
}
## Connect to viserver with logged on user
if (!$vCenteruser -and !$vCenterpass -and !$connectedserver){
	Write-output "Connecting to vCenter $VCServer as logged on user $loggedonuser...`r`n"
	Connect-VIServer $VCServer -ErrorVariable ErrorProcess -ErrorAction SilentlyContinue
}
## Connect to viserver with username and password provided
if ($vCenteruser -ne '' -and $vCenterpass -ne '' -and !$connectedserver){
	Write-output "Connecting to vCenter $VCServer as $vCenteruser...`r`n"
	Connect-VIServer $VCServer -user $vCenteruser -password $vCenterpass -ErrorVariable ErrorProcess -ErrorAction SilentlyContinue
}


if($ErrorProcess){
    Write-Warning "Error connecting to vCenter Server $VCServer error message below"
    Write-Warning $Error[0].Exception.Message
    #$Error[0].Exception.Message | Out-File $ReportExport\ConnectionError.txt
	$Error[0].Exception.Message | Out-File $ReportExport\ConnectionError.txt
exit
    }

else
{

## Create results array
$results = @()

## Get distributed port groups
$portGroups = Get-VirtualPortgroup | sort-object Name -unique |  Select-Object Name,vlanid

## Loop through each port group
foreach ($port in $portGroups) {

Write-Host "Checking VMs on " $port.name " "$port.vlanid -foreground green

## Get port group view and add addtionaly properties
$networks = Get-View -ViewType Network -Property Name -Filter @{"Name" = $($port.name)}
$networks | ForEach-Object{($_.UpdateViewData("Vm.Name","Vm.Runtime.Host.Name","Vm.Runtime.Host.Parent.Name"))}

## Loop through each view
foreach ($network in $networks){

## Get VM's
$vms = $network.LinkedView.Vm

## Check if any data in VMS variable
if (!$vms){
$vlanid = Get-VirtualPortgroup -name $network.Name | select vlanid | sort-object vlanid -unique
$vlanid_string = $vlanid.vlanid -as [int]
#if (($vlanid_string -ne '0') -or ($vlanid_string -lt '250' -and $vlanid_string -gt '255')){
if (($vlanid_string -ne '0')){	
## Create hash table for properties
$properties = @{
PortGroup = $network.Name
VLANid = $vlanid_string
 
}
$count = $count+1

## Export results
$results += New-Object pscustomobject -Property $properties
}
        }
    }
}

## Output to console
if ($ConsoleOnly){
$results | Select-Object PortGroup,VLANid
write-output $count
}

## Export resutls 
elseif ($ReportExport){
$results | Select-Object PortGroup,VLANid
write-output $count	
$results | Select-Object PortGroup,VLANid | 
Export-csv '.\PortGroupExport.csv' -NoTypeInformation
    }
}
if ($connectedserver){
Disconnect-VIServer -Server $VCServer -Confirm:$False}
