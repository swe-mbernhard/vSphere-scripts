# vSphere-add-vlan-GUI

Powershell script to add VLAN portgroups to all ESXi managed by a vSphere server. 

# Prerequisites

A vcenter server, esx cluster, and vSwitch with the same name throughout the ESXi servers. 

Tested on vSphere 6.7 with ESXi hosts 6.7.

# Usage

Run the powershell script - **script will check for, and install the following ps1 modules:** 

PSIni

VMware.PowerCLI

NuGet


# Commandline switches

Following switches are available:

/debug - Extensive output

/switch \<vswitchname\> Specify vSwitch name 
 
 /vcenterserver \<vcenterserverfqdn\> Specify vcenter server FQDN or IP address
 
 # Disclaimer
 
THE SCRIPTS IN THIS REPOSITORY ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. You are responsible for ensuring that any scripts you execute does not contain malicious code, or does not cause unwanted changes to your environment. If you do not understand what the code does, do not blindly execute it! A script has access to the full power of the vsphere environment. Do not execute a script from sources you do not trust.
 
 With that said, I use it in a production environment. 
