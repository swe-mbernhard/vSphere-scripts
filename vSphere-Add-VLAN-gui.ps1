 param (
    [switch]$debug,
	[string]$switch,
	[string]$vCenterServer
    )
	
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
# Init PowerShell Gui
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#######################
## Script to add VLAN to all ESXi servers. 
#######################



#---------------------------------------------------------[Variables]--------------------------------------------------------
$version = "1.0"


#---------------------------------------------------------[Read ini]--------------------------------------------------------

function Get-IniFile 
{  
    param(  
        [parameter(Mandatory = $true)] [string] $filePath  
    )  
    
    $anonymous = "NoSection"
  
    $ini = @{}  
    switch -regex -file $filePath  
    {  
        "^\[(.+)\]$" # Section  
        {  
            $section = $matches[1]  
            $ini[$section] = @{}  
            $CommentCount = 0  
        }  

        "^(;.*)$" # Comment  
        {  
            if (!($section))  
            {  
                $section = $anonymous  
                $ini[$section] = @{}  
            }  
            $value = $matches[1]  
            $CommentCount = $CommentCount + 1  
            $name = "Comment" + $CommentCount  
            $ini[$section][$name] = $value  
        }   

        "(.+?)\s*=\s*(.*)" # Key  
        {  
            if (!($section))  
            {  
                $section = $anonymous  
                $ini[$section] = @{}  
            }  
            $name,$value = $matches[1..2]  
            $ini[$section][$name] = $value  
        }  
    }  

    return $ini  
} 

$test_for_ini_path = (Test-Path -Path "$env:APPDATA\VmWare Scripting")
if (!$test_for_ini_path)
{
	[void](New-Item -ItemType Directory -Path "$env:APPDATA\VmWare Scripting")
}

$test_for_ini = (Test-Path -Path "$env:APPDATA\VmWare Scripting\addvlan.ini" -PathType Leaf)
if ($test_for_ini)
{
$inifile = get-iniFile "$env:APPDATA\VmWare Scripting\addvlan.ini"
$vCenterServer = $inifile.vcenter.name
$switch = $inifile.vcenter.vswitch
$vCenteruser = $inifile.vcenter.vcenteruser
}



if (!$switch)
{
$switch = "vSwitch0"
}



#---------------------------------------------------------[Create base64 logo image]--------------------------------------------------------
$base64_logo = "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"
$imageBytes = [Convert]::FromBase64String($base64_logo)
$ms = New-Object IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
$ms.Write($imageBytes, 0, $imageBytes.Length);
$logo = [System.Drawing.Image]::FromStream($ms, $true)


#---------------------------------------------------------[Form]--------------------------------------------------------

[System.Windows.Forms.Application]::EnableVisualStyles()

## Add vlan form

$LocalVLANForm					= New-Object system.Windows.Forms.Form
$LocalVLANForm.ClientSize		= '480,800'
$LocalVLANForm.text				= "Add ESXi VLANs v$version"
$LocalVLANForm.BackColor		= "#ffffff"
$LocalVLANForm.TopMost			= $false
$LocalVLANForm.FormBorderStyle	= 'Fixed3D'

$Titel							= New-Object system.Windows.Forms.Label
$Titel.text						= "Add VLAN to ESXi"
$Titel.AutoSize					= $true
$Titel.width					= 25
$Titel.height					= 10
$Titel.location					= New-Object System.Drawing.Point(20,20)
$Titel.Font						= 'Microsoft Sans Serif,13'

$Description					= New-Object system.Windows.Forms.Label
$Description.text				= "Add VLAN to hosts in $vCenterServer cluster."
$Description.AutoSize			= $false
$Description.width				= 400
$Description.height				= 30
$Description.location			= New-Object System.Drawing.Point(20,50)
$Description.Font				= 'Microsoft Sans Serif,10'

$VLANNameLabel                	= New-Object system.Windows.Forms.Label
$VLANNameLabel.text           	= "VLAN Name:"
$VLANNameLabel.AutoSize       	= $true
$VLANNameLabel.width          	= 25
$VLANNameLabel.height         	= 20
$VLANNameLabel.location       	= New-Object System.Drawing.Point(20,180)
$VLANNameLabel.Font           	= 'Microsoft Sans Serif,10,style=Bold'
$VLANNameLabel.Visible       	= $true

$VLANName                     	= New-Object system.Windows.Forms.TextBox
$VLANName.multiline           	= $false
$VLANName.width               	= 200
$VLANName.height              	= 40
$VLANName.location            	= New-Object System.Drawing.Point(20,200)
$VLANName.Font                	= 'Microsoft Sans Serif,10'
$VLANName.Visible             	= $true
$VLANName.TabIndex 				= 1

$vcenterLabel                	= New-Object system.Windows.Forms.Label
$vcenterLabel.text           	= "vCenter Name:"
$vcenterLabel.AutoSize       	= $true
$vcenterLabel.width          	= 25
$vcenterLabel.height         	= 20
$vcenterLabel.location       	= New-Object System.Drawing.Point(20,80)
$vcenterLabel.Font           	= 'Microsoft Sans Serif,10,style=Bold'
$vcenterLabel.Visible        	= $true

$vcenterName					= New-Object system.Windows.Forms.TextBox
$vcenterName.multiline			= $false
$vcenterName.text				= $vCenterServer
$vcenterName.width				= 200
$vcenterName.height				= 40
$vcenterName.location			= New-Object System.Drawing.Point(20,100)
$vcenterName.Font				= 'Microsoft Sans Serif,10'
$vcenterName.Visible			= $true
$vcenterName.TabIndex 			= 3

$vcuserLabel                	= New-Object system.Windows.Forms.Label
$vcuserLabel.text           	= "vCenter Username (optional):"
$vcuserLabel.AutoSize       	= $true
$vcuserLabel.width          	= 25
$vcuserLabel.height         	= 20
$vcuserLabel.location       	= New-Object System.Drawing.Point(240,80)
$vcuserLabel.Font           	= 'Microsoft Sans Serif,10,style=Bold'
$vcuserLabel.Visible        	= $true

$vcuserName                     = New-Object system.Windows.Forms.TextBox
$vcuserName.multiline           = $false
$vcuserName.width               = 200
$vcuserName.height              = 40
$vcuserName.location            = New-Object System.Drawing.Point(240,100)
$vcuserName.Font                = 'Microsoft Sans Serif,10'
$vcuserName.Visible             = $true
$vcuserName.Text				= $vCenteruser
$vcuserName.TabIndex 			= 5

$vcpassLabel                	= New-Object system.Windows.Forms.Label
$vcpassLabel.text           	= "vCenter Password (optional):"
$vcpassLabel.AutoSize       	= $true
$vcpassLabel.width          	= 25
$vcpassLabel.height         	= 20
$vcpassLabel.location       	= New-Object System.Drawing.Point(240,130)
$vcpassLabel.Font          		= 'Microsoft Sans Serif,10,style=Bold'
$vcpassLabel.Visible        	= $true

$vcpass                     	= New-Object system.Windows.Forms.TextBox
$vcpass.multiline           	= $false
$vcpass.PasswordChar 			= '*'
$vcpass.width               	= 200
$vcpass.height              	= 40
$vcpass.location            	= New-Object System.Drawing.Point(240,150)
$vcpass.Font                	= 'Microsoft Sans Serif,10'
$vcpass.Visible             	= $true
$vcpass.TabIndex 				= 6


$VLANIDLabel                	= New-Object system.Windows.Forms.Label
$VLANIDLabel.text           	= "VLAN ID:"
$VLANIDLabel.AutoSize       	= $true
$VLANIDLabel.width          	= 25
$VLANIDLabel.height         	= 20
$VLANIDLabel.location       	= New-Object System.Drawing.Point(20,230)
$VLANIDLabel.Font           	= 'Microsoft Sans Serif,10,style=Bold'
$VLANIDLabel.Visible        	= $true

$VLANIDName                     = New-Object system.Windows.Forms.TextBox
$VLANIDName.multiline           = $false
$VLANIDName.width               = 200
$VLANIDName.height              = 40
$VLANIDName.location            = New-Object System.Drawing.Point(20,250)
$VLANIDName.Font                = 'Microsoft Sans Serif,10'
$VLANIDName.Visible             = $true
$VLANIDName.TabIndex 			= 2

$vswitchLabel                	= New-Object system.Windows.Forms.Label
$vswitchLabel.text           	= "Existing vSwitch name:"
$vswitchLabel.AutoSize       	= $true
$vswitchLabel.width          	= 25
$vswitchLabel.height         	= 20
$vswitchLabel.location       	= New-Object System.Drawing.Point(20,130)
$vswitchLabel.Font           	= 'Microsoft Sans Serif,10,style=Bold'
$vswitchLabel.Visible        	= $true

$vswitchName                    = New-Object system.Windows.Forms.TextBox
$vswitchName.multiline          = $false
$vswitchName.width              = 200
$vswitchName.height             = 40
$vswitchName.location           = New-Object System.Drawing.Point(20,150)
$vswitchName.Font               = 'Microsoft Sans Serif,10'
$vswitchName.Visible            = $true
$vswitchName.text				= $switch
$vswitchName.TabIndex 			= 4

$dryrunchkboxlabel				= New-Object system.Windows.Forms.Label
$dryrunchkboxlabel.AutoSize		= $true
$dryrunchkboxlabel.width		= 25
$dryrunchkboxlabel.height		= 20
$dryrunchkboxlabel.text			= "Dry-run - try but do not change."
$dryrunchkboxlabel.location		= New-Object System.Drawing.Point(240,180)
$dryrunchkboxlabel.Font			= 'Microsoft Sans Serif,10,style=Bold'
$dryrunchkboxlabel.Visible		= $true

$dryrunchkbox                	= New-Object system.Windows.Forms.Checkbox
$dryrunchkbox.location       	= New-Object System.Drawing.Point(240,200)
$dryrunchkbox.Visible       	= $true
$dryrunchkbox.Checked 		 	= $false 
$dryrunchkbox.TabIndex 			= 7

$StatusLabel                	= New-Object system.Windows.Forms.Label
$StatusLabel.text           	= "Status:"
$StatusLabel.AutoSize       	= $true
$StatusLabel.width          	= 25
$StatusLabel.height         	= 20
$StatusLabel.location       	= New-Object System.Drawing.Point(20,320)
$StatusLabel.Font           	= 'Microsoft Sans Serif,10,style=Bold'
$StatusLabel.Visible        	= $true

$addStatus                   	= New-Object system.Windows.Forms.RichTextBox
$addStatus.multiline         	= $true
$addStatus.Scrollbars 		 	= "Both"
$addStatus.AutoSize          	= $true
$addStatus.width             	= 440
$addStatus.height            	= 380
$addStatus.location          	= New-Object System.Drawing.Point(20,350)
$addStatus.Font              	= 'Microsoft Sans Serif,8'
$addStatus.Visible          	= $true


$FormImg = New-Object System.Windows.Forms.PictureBox 
$FormImg.Location = New-Object System.Drawing.Point(100,730) 
$FormImg.Width =  $logo.Size.Width;
$FormImg.Height =  $logo.Size.Height;
$FormImg.Image = $logo


$AddVLANBtn                   	= New-Object system.Windows.Forms.Button
$AddVLANBtn.BackColor         	= "#ff7b00"
$AddVLANBtn.text              	= "Run"
$AddVLANBtn.width             	= 90
$AddVLANBtn.height            	= 30
$AddVLANBtn.location          	= New-Object System.Drawing.Point(120,290)
$AddVLANBtn.Font              	= 'Microsoft Sans Serif,10'
$AddVLANBtn.ForeColor         	= "#ffffff"
$AddVLANBtn.Visible           	= $true
$AddVLANBtn.TabIndex 			= 9

$cancelBtn						= New-Object system.Windows.Forms.Button
$cancelBtn.BackColor			= "#ffffff"
$cancelBtn.text					= "Cancel"
$cancelBtn.width				= 90
$cancelBtn.height				= 30
$cancelBtn.location				= New-Object System.Drawing.Point(260,290)
$cancelBtn.Font					= 'Microsoft Sans Serif,10'
$cancelBtn.ForeColor			= "#000"
$cancelBtn.DialogResult			= [System.Windows.Forms.DialogResult]::Cancel

$ClearButton = New-Object System.Windows.Forms.Button;
$ClearButton.Location = New-Object System.Drawing.Point(20,290)
$ClearButton.width				= 90
$ClearButton.height				= 30
$ClearButton.Font               = 'Microsoft Sans Serif,10'
$ClearButton.Visible            = $true
$ClearButton.Text               = "Clear status"
$ClearButton.TabIndex 			= 8
$ClearButton.Add_Click{$addStatus.Clear()}


$QuitButton = New-Object System.Windows.Forms.Button;
$QuitButton.Location = New-Object System.Drawing.Point(370,290)
$QuitButton.width				= 90
$QuitButton.height				= 30
$QuitButton.Font               	= 'Microsoft Sans Serif,10'
$QuitButton.Visible            	= $true
$QuitButton.BackColor         	= "#FF7676"
$QuitButton.Text               	= "Exit"
$QuitButton.TabIndex 			= 11
$QuitButton.DialogResult		= [System.Windows.Forms.DialogResult]::Cancel

$HelpButton = New-Object System.Windows.Forms.Button;
$HelpButton.Location = New-Object System.Drawing.Point(220,290)
$HelpButton.width				= 90
$HelpButton.height				= 30
$HelpButton.Font               	= 'Microsoft Sans Serif,10'
$HelpButton.Visible            	= $true
$HelpButton.Text               	= "Help"
$HelpButton.TabIndex 			= 10


$LocalVLANForm.CancelButton   = $QuitButton
$LocalVLANForm.controls.AddRange(@($Titel,$Description,$FormImg,$VLANName,$vswitchName,$vswitchLabel,$VLANNameLabel,$VLANIDName,$StatusLabel,$dryrunchkboxlabel,$vcuserName, $dryrunchkbox, $vcuserlabel,$vcpass,$vcpasslabel, $VLANIDLabel,$ClearButton,$vcenterLabel,$vcentername,$addStatus,$AddVLANBtn,$QuitButton,$HelpButton))
$LocalVLANForm.add_Shown({CheckPowerCLI })
$LocalVLANForm.add_Shown({CheckPSini })
$LocalVLANForm.add_Shown({Checknuget })
$AddVLANBtn.Add_Click({ AddVLAN })

## HELP form
$HelpForm                    	= New-Object system.Windows.Forms.Form
$HelpForm.ClientSize         	= '480,330'
$HelpForm.text               	= "Help v$version"
$HelpForm.BackColor          	= "#ffffff"
$HelpForm.TopMost            	= $false
$HelpForm.Visible            	= $false
$HelpForm.FormBorderStyle 		= 'Fixed3D'

$HelpName                    	= New-Object system.Windows.Forms.RichTextBox
$HelpName.multiline           	= $true
$HelpName.width               	= 470
$HelpName.height              	= 270
$HelpName.location            	= New-Object System.Drawing.Point(5,5)
$HelpName.Font                	= 'Microsoft Sans Serif,8'
$HelpName.Visible			  	= $true
$HelpName.ReadOnly		      	= $true
$HelpName.Text				  	= "Add VLANs to all ESXi`r`n`r`n"
$HelpName.Text 					+=   "Enter a VLAN name and number (VLAN ID) to add to default vCenter servers.`r`n`r`n";
$HelpName.Text 					+=   "Enter another vCenter server if you want to connect to another system than $vCenterServer.`r`n`r`n";
$HelpName.Text 					+=   "vSwitch option must be set to an existing vSwitch with the same name on all hosts. Default $switch`r`n`r`n";
$HelpName.Text 					+=   "If no username or password is provided, the application runs as the user your are logged in as.`r`n`r`n";
$HelpName.Text 					+=   "The form checks input data for sanity.`r`n`r`n";
$HelpName.Text 					+=   "Use Dry-run if you want to check for sanity and already added VLANs`r`n`r`n";
$HelpName.Text 					+=   "Default vswitch and vcenter can be set by variables in addvlan.ini file.`r`n`r`n";
$HelpName.Text 					+=   "The running version is $version.`r`n";


$QuitButton = New-Object System.Windows.Forms.Button;
$QuitButton.Location = New-Object System.Drawing.Point(385,285)
$QuitButton.width				= 90
$QuitButton.height				= 30
$QuitButton.Font               	= 'Microsoft Sans Serif,10'
$QuitButton.Visible            	= $true
$QuitButton.BackColor         	= "#FF7676"
$QuitButton.Text               	= "Exit"
$QuitButton.DialogResult		= [System.Windows.Forms.DialogResult]::Cancel

$HelpForm.CancelButton   		= $QuitButton

$HelpButton.Add_Click({ [void]$HelpForm.ShowDialog() })

$HelpForm.controls.AddRange(@($HelpName,$QuitButton))

#######################
# Start functions
#######################


#######################
# Append status text to textarea
#######################

function Append-ColoredLine {
    param( 
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Windows.Forms.RichTextBox]$box,
        [Parameter(Mandatory = $true, Position = 1)]
        [System.Drawing.Color]$color,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$text
    )
    $box.SelectionStart = $box.TextLength
    $box.SelectionLength = 0
    $box.SelectionColor = $color
    $box.AppendText($text)
	$box.ScrollToCaret()
}
#######################
# Check for installed packages
#######################

function checknuget {
	$NuGetProviderCheck = Get-packageprovider -listavailable | where-object{$_.Name -like "NuGet"}
		if ($NuGetProviderCheck -eq $null)
		{
			Append-ColoredLine $addStatus Red "NuGet Provider Not Found. Installing, please wait.`r`n"
			if ((Get-PSRepository -Name "PSGallery").InstallationPolicy -ne "Trusted") {
				Set-PSRepository "PSGallery" -InstallationPolicy "Trusted"
				}
			Install-PackageProvider -Name NuGet -Force -Scope CurrentUser

			$NuGetProviderCheck = Get-packageprovider -listavailable | where-object{$_.Name -like "NuGet"}
					if ($NuGetProviderCheck -eq $null)
					{
						Append-ColoredLine $addStatus DarkCyan "Something went wrong. Provider NuGet not installed.`r`nTry manual install as admin: Install-PackageProvider -Name NuGet -Force`r`nExiting.."	
					}
					else{
						Append-ColoredLine $addStatus DarkCyan "Installation of NuGet Provider complete, good to go.`r`n"
					}
		}
		else 
		{
		Append-ColoredLine $addStatus DarkCyan "NuGet Provider Found, good to go.`r`n"

		}
			$NuGetmoduleCheck = Get-Module -ListAvailable -Name NuGet
		if ($NuGetProviderCheck -eq $null)
		{
			Append-ColoredLine $addStatus Red "NuGet Script module Not Found. Installing, please wait.`r`n"
			Install-Module -Name NuGet -Force -scope CurrentUser
			$NuGetmoduleCheck = Get-Module -ListAvailable -Name NuGet
					if ($NuGetmoduleCheck -eq $null)
					{
						Append-ColoredLine $addStatus DarkCyan "Something went wrong. Module NuGet not installed.`r`nTry manual install as admin: Install-Module -Name NuGet -Force`r`nExiting.."	
					}
					else{
						Append-ColoredLine $addStatus DarkCyan "Installation of NuGet Script module complete, good to go.`r`n"
					}
		}
		else 
		{
		Append-ColoredLine $addStatus DarkCyan "NuGet Script module Found, good to go.`r`n"

		}
}




function CheckPowerCLI {
	$PowerCLIModuleCheck = Get-Module -ListAvailable VMware.PowerCLI
		if ($PowerCLIModuleCheck -eq $null)
		{
			Append-ColoredLine $addStatus Red "PowerCLI Module Not Found. Installing, please wait.`r`n"
			if ((Get-PSRepository -Name "PSGallery").InstallationPolicy -ne "Trusted") {
				Set-PSRepository "PSGallery" -InstallationPolicy "Trusted"
				}
			Install-Module -Scope CurrentUser -Name VMware.PowerCLI -SkipPublisherCheck -AllowClobber -Confirm:$false
			Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
			Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
			$PowerCLIModuleCheck = Get-Module -ListAvailable VMware.PowerCLI
					if ($PowerCLIModuleCheck -eq $null)
					{
						Append-ColoredLine $addStatus DarkCyan "Something went wrong. Module VMware.PowerCLI not installed.`r`nTry manual install as admin: Install-Module -Scope CurrentUser -Name VMware.PowerCLI -SkipPublisherCheck -AllowClobber`r`nExiting.."	
					}
					else{
						Append-ColoredLine $addStatus DarkCyan "Installation complete, good to go.`r`n"
					}
		}
		else 
		{
		Append-ColoredLine $addStatus DarkCyan "PowerCLI Module Found, good to go.`r`n"
		#Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
		#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
		}
}
function CheckPSIni {
	$PSIniModuleCheck = Get-Module -ListAvailable PSIni
		if ($PSIniModuleCheck -eq $null)
		{
			Append-ColoredLine $addStatus Red "PSIni Module Not Found. Installing, please wait.`r`n"
			if ((Get-PSRepository -Name "PSGallery").InstallationPolicy -ne "Trusted") {
				Set-PSRepository "PSGallery" -InstallationPolicy "Trusted"
				}
			Install-Module PSini -Scope CurrentUser

			$PSIniModuleCheck = Get-Module -ListAvailable VMware.PowerCLI
					if ($PSIniModuleCheck -eq $null)
					{
						Append-ColoredLine $addStatus DarkCyan "Something went wrong. Module PSIni not installed.`r`nTry manual install as admin: Install-Module PSIni`r`nExiting.."	
					}
					else{
						Append-ColoredLine $addStatus DarkCyan "Installation of PSIni complete, good to go.`r`n"
					}
		}
		else 
		{
		Append-ColoredLine $addStatus DarkCyan "PSIni Module Found, good to go.`r`n"
		#Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
		#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
		}
}



#######################
# Check VLAN ID for integer
#######################
Function IsValidvlanid ([string]$fnInteger)
{ 
Try {
    $Null = [convert]::ToInt32($fnInteger)
   
	Return $True
}
Catch {Return $False}
}

#######################
# Add VLAN function
#######################

function AddVLAN { 
$vlanname = $VLANName.text
$MyVLANid = $VLANIDName.text
$vCenter = $vcenterName.text
$vCenteruser = $vcuserName.text
$vCenterpass = $vcpass.text
$switch = $vswitchName.text
$connectedserver = $global:defaultviserver
$loggedonuser = ((Get-WMIObject -class Win32_ComputerSystem | Select-Object -ExpandProperty username)) 
## Error handling

if ((!(IsValidvlanid($MyVLANid))) -or ([convert]::ToInt32($MyVLANid, 10) -lt 1 -or [convert]::ToInt32($MyVLANid, 10) -gt 4096))
{
	Append-ColoredLine $addStatus Red "EXCEPTION: Invalid VLAN ID, must be integer between 1 and 4096. Stopping right here.`r`n"
	$exit = "yes"
	
}
if ($vlanname -notmatch '^[a-zA-Z0-9\.\-_]{1,15}$')
	{
	Append-ColoredLine $addStatus Red "EXCEPTION: Invalid VLAN name. Use letters and numbers only, dots, dashes and underscores are OK. Max 15 characters.`r`n"
	$exit = "yes"
	}	

## Check if powercli is connected to viserver, then disconnect
if ($connectedserver)
{
	Append-ColoredLine $addStatus Green "Disconnecting from already connected vCenter $global:defaultviserver.`r`n"
	Disconnect-VIServer -Server $connectedserver -Confirm:$False	
	$connectedserver = $null
}
## Connect to viserver with logged on user
if (!$vCenteruser -and !$vCenterpass -and !$connectedserver -and $exit -ne 'yes'){
	Append-ColoredLine $addStatus Green "Connecting to vCenter $vCenter as logged on user $loggedonuser...`r`n"
	Connect-VIServer $vCenter -ErrorVariable badoutput
}
## Connect to viserver with username and password provided
if ($vCenteruser -ne '' -and $vCenterpass -ne '' -and !$connectedserver -and $exit -ne 'yes'){
	Append-ColoredLine $addStatus Green "Connecting to vCenter $vCenter as $vCenteruser...`r`n"
	Connect-VIServer $vCenter -user $vCenteruser -password $vCenterpass -ErrorVariable badoutput
}

$connectedserver = $global:defaultviserver

## If connection is successful and no other errors are found, start evaluating. 

if ($connectedserver -and $exit -ne 'yes'){

if ($exit -ne "yes"){

If(-not($vCenter)){$vCenter = $vCenterServer}
##If(-not($cluster)){$cluster = 'DatacenterDC02 CubeOne Datacenter'}
#If(-not($switch)){ $switch = 'vSwitch0'}

$getnumhosts = Foreach($vc in $global:DefaultVIServers)
	{
		New-Object -TypeName PSObject -Property @{
        vCenter = $vc.Name
        HostCount = (Get-VMHost -Server $vc).count
    }
}
$num_hosts = $getnumhosts.hostcount

$MyVMHosts = Get-Cluster | Get-VMHost | sort Name | % {$_.Name}

  # Loop through the hosts and add the virtual port group to our vswitch based on the input

  ForEach ($VMHost in $MyVMHosts) {
	  $vlanID_exists = 0
	  $vlanname_exists = 0
	if  ((get-virtualswitch -name $switch -host $VMHost).Name -notcontains $switch)
	{
	 	Append-ColoredLine $addStatus Red "EXCEPTION: $VMHost do not have $switch. Nothing to do on this host.`r`n"
		continue
	}
	if (((Get-VirtualPortGroup -host $VMHost).VLanId -contains $MyVLANid) )
		{
		$vlanID_exists = 1
		$existingpgname = Get-VirtualPortGroup -host $VMHost | select name,vlanid -ExpandProperty name| where{$_.vlanid -contains $MyVLANid}
		$existingpgnamecount = $existingpgnamecount+1
		Append-ColoredLine $addStatus DarkCyan "INFO: $VMHost has VLAN ID $MyVLANid by the name $existingpgname`r`n"
		}
	if ((Get-VirtualPortGroup -host $VMHost).name -ccontains $vlanname) 
		{
		$vlanname_exists = 1
		$existingvlannamecount = $existingvlannamecount +1
		$existingvlanname = Get-VirtualPortGroup -host $VMHost | select name -ExpandProperty name | where{$_.Name -contains $vlanname} 
		Append-ColoredLine $addStatus DarkCyan "INFO: $VMHost has VLAN name $existingvlanname present. Not adding anything.`r`n"
		}
	elseif ((Get-VirtualPortGroup -host $VMHost).name -contains $vlanname) 
		{
		$vlanname_exists = 1
		$existingvlannamecount = $existingvlannamecount +1
		$existingvlanname = Get-VirtualPortGroup -host $VMHost | select name -ExpandProperty name | where{$_.Name -contains $vlanname} 
		Append-ColoredLine $addStatus DarkCyan "INFO: $VMHost Consider changing input name to $existingpgname and re-run script.`r`n"
		}

	if ($vlanname_exists -eq 1)
		{
			Append-ColoredLine $addStatus DarkCyan "INFO: $VMHost has VLAN $vlanname. Nothing to do.`r`n"

		}
	if ($vlanID_exists -eq 1)
		{
		Append-ColoredLine $addStatus DarkCyan "INFO: $VMHost has VLAN ID $MyVLANid. Nothing to do.`r`n"

		}
	if ($vlanname_exists -eq 0 -and $vlanID_exists -eq 0)
		{
		if ($dryrunchkbox.checked -eq $false){
			Append-ColoredLine $addStatus Black "ACTION: $VMHost Adding VLAN $vlanname with ID $MyVLANid to $VMHost.`r`n"
			## Add the VLANs
			get-cluster  | Get-VMHost -name $VMHost | Get-VirtualSwitch -name $switch | New-VirtualPortGroup -Name $vlanname -VLanId $MyVLANid | out-null
		
		if ($?) {
			$summary = $summary+"SUMMARY: $VMHost VLAN with name $vlanname and ID $MyVLANid`r`n"
		}
		}
		else {
			Append-ColoredLine $addStatus Black "DRYRUN: $VMHost Adding VLAN $vlanname with ID $MyVLANid.`r`n"
		}
		
		}

  }

	if ($existingpgnamecount -eq $num_hosts)
		{
		Append-ColoredLine $addStatus Red "EXCEPTION: All hosts has VLAN $vlanname or VLAN ID:$MyVLANid. Nothing to do.`r`n"
		}


	}

else {
	Append-ColoredLine $addStatus Red "EXCEPTION: One or more exceptions caught. Review your data.`r`n"
}
	

$addStatus.AppendText($summary)
Disconnect-VIServer -Server $vCenter -Confirm:$False
Append-ColoredLine $addStatus Green "INFO: Disconnecting and Exiting.`r`n"



}
else {
	if ($exit -ne 'yes'){
	$psoutput = $badoutput -replace '\s+', ' '
	Append-ColoredLine $addStatus Red "Failed to connect to vcenter.`r`n$psoutput`r`n"
	}
	Append-ColoredLine $addStatus Green "Please try again.`r`n"
}
##
# Write values to ini
##
if ($test_for_ini){
	$ini = Get-IniContent "$env:APPDATA\VmWare Scripting\addvlan.ini"
	$ini["vcenter"]["name"] = $vCenter
$ini["vcenter"]["vswitch"] = $switch
$ini["vcenter"]["vcenteruser"] = $vCenteruser
$ini | Out-IniFile -Force -FilePath .\addvlan.ini
Append-ColoredLine $addStatus Green "INFO: Updating values in addvlan.ini.`r`n"
}

else
{
        $Category1 = @{"name"="$vCenter";"vswitch"="$switch";"vcenteruser"="$vCenteruser"}
        $NewINIContent = @{"vcenter"=$Category1}
        Out-IniFile -InputObject $NewINIContent -FilePath "$env:APPDATA\VmWare Scripting\addvlan.ini"
		Append-ColoredLine $addStatus Green "INFO: Creating and adding values to addvlan.ini.`r`n"
}
}
[void]$LocalVLANForm.ShowDialog()
