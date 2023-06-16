# vSphere-add-vlan-GUI

Powershell script to add VLAN portgroups to all ESXi managed by a vSphere server. 

# Prerequisites

A vcenter server, esx cluster, and vSwitch with the same name throughout the ESXi servers. 

Tested on vSphere 6.7 with ESXi hosts 6.7.

# Usage

Run the powershell script - will check for, and install the following ps1 modules: 

PSIni
VMware.PowerCLI

NuGet


# Commandline switches

Following switches are available:

/debug - Extensive output

/switch <vswitchname> Specify vSwitch name 
 
 /vcenterserver <vcenterserverfqdn> Specify vcenter server
