<#
    .Synopsis
    Creates a big demo lab.
    .DESCRIPTION
    Huge Thank you to Ben Armstrong @VirtualPCGuy for giving me the source starter code for this :)
    TODO: Dave, add something more meaningful in here.
    .EXAMPLE
    TODO: Dave, add something more meaningful in here
    .PARAMETER WorkingDir
    Transactional directory for files to be staged and written
    .PARAMETER Organization
    Org that the VMs will belong to
    .PARAMETER Owner
    Name to fill in for the OSs Owner field
    .PARAMETER TimeZone
    Timezone used by the VMs
    .PARAMETER AdminPassword
    Administrative password for the VMs
    .PARAMETER DomainName
    AD Domain to setup/join VMs to
    .PARAMETER DomainAdminPassword
    Domain recovery/admin password
    .PARAMETER VirtualSwitchName
    Name of the vSwitch for Hyper-V
    .PARAMETER Subnet
    The /24 Subnet to use for Hyper-V networking
#>

[cmdletbinding()]
param
( 
    [Parameter(Mandatory)]
    [ValidateScript({ $_ -match '[^\\]$' })] #ensure WorkingDir does not end in a backslash, otherwise issues are going to come up below
    [string]
    $WorkingDir = 'D:\DCBuild',

    [Parameter(Mandatory)]
    [string]
    $Organization = 'MVP Rockstars',

    [Parameter(Mandatory)]
    [string]
    $Owner = 'Dave Kawula',

    [Parameter(Mandatory)]
    [ValidateScript({ $_ -in ([System.TimeZoneInfo]::GetSystemTimeZones()).ID })] #ensure a valid TimeZone was passed
    [string]
    $Timezone = 'Pacific Standard Time',

    [Parameter(Mandatory)]
    [string]
    $adminPassword = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $domainName = 'MVPDays.Com',

    [Parameter(Mandatory)]
    [string]
    $domainAdminPassword = 'P@ssw0rd',

    [Parameter(Mandatory)]
    [string]
    $virtualSwitchName = 'Dave MVP Demo',

    [Parameter(Mandatory)]
    [ValidatePattern('(\d{1,3}\.){3}')] #ensure that Subnet is formatted like the first three octets of an IPv4 address
    [string]
    $Subnet = '172.16.200.',

    [Parameter(Mandatory)]
    [string]
    $ExtraLabfilesSource = 'd:\DCBuild\Extralabfiles'


)

#region Functions

function Wait-PSDirect
{
     param
     (
         [string]
         $VMName,

         [Object]
         $cred
     )

    Write-Log $VMName "Waiting for PowerShell Direct (using $($cred.username))"
    while ((Invoke-Command -VMName $VMName -Credential $cred {
                'Test'
    } -ea SilentlyContinue) -ne 'Test') 
    {
        Start-Sleep -Seconds 1
    }
}

function Stage-Labfiles
{
    param
      (
         [string]
         $VMName
               
     )


    Wait-PSDirect $VMName -cred $domainCred
    Write-Output -InputObject "[$(VMName)]:: Copying Labfiles from Host to Management Server"
    Get-ChildItem $ExtraLabfilesSource -Recurse -File | % { Copy-VMFile $vmname -SourcePath $_.FullName -DestinationPath $_.FullName -CreateFullPath -FileSource Host }
}

function Stage-Labfiles
{
    param
      (
         [string]
         $VMName
               
     )


    Wait-PSDirect $VMName -cred $localCred
    Write-Output -InputObject "[$(VMName)]:: Copying Labfiles from Host to Management Server"
    Get-ChildItem D:\DCBuild\ExtraLabFiles -Recurse -File | % { Copy-VMFile $vmname -SourcePath $_.FullName -DestinationPath $_.FullName -CreateFullPath -FileSource Host }
}

function Build-Internet
#My Bonus for the Lab --> Why not have it fully routable across many many different subnets, DHCP Relay, Simulated Internet, Great if you want to add Stuff Like Direct Access and test it.
{
  param
      (
         [string]
         $VMName
               
     )

$Router = $VMName
$VSwitch = "PRIVATE-VLAN200"
$Vswitch_Internet = "Private_Internet"
$Vswitch_Internet2 = "Private_Internet2" 
$Vswitch_CYL = "Private_CYL"
$Vswitch_CYL2 = "Private_VLAN30"
$Vswitch_DMZ = "Private_CYLDMZ"
$Vswitch_DMZ2 = "Private_CYLDMZ2"
$IPAddress = "172.16.200.210"
$IPAddress_CYL2 = "192.168.3.210"
$IPAddress_Internet = "1.1.1.1"
$IPAddress_DHCPRelay = "1.1.1.2"
$IPAddress_DMZ = "172.16.100.210"
$IPAddress_DMZ2 = "172.16.201.210"
$IPAddress_Internet2 = "2.2.2.1"
$IPAddress_DHCPRelay2 = "2.2.2.2"
$VMLocation = "F:\VMs"
$DC = "DC1"
$Router_HV = $VMName
$INTERNET_HV = "INTERNET_CYL"
$EXTERNALDNS = "INTERNET"
$INTERNET_IP = "1.1.1.3"
$DHCPServer = "DHCP Server"

#Create VSWITCH INTERNAL-VLANxx and INTERNAL-INTERNET ($VSwitch) 
Write-Host "Creating the VSwitches for the Lab" -ForegroundColor Yellow
Write-Host "Stopping $router_HV" -ForegroundColor Yellow 
Stop-VM -Name $router_HV -Confirm:$false -Force -WarningAction SilentlyContinue | Out-Null
Wait-Sleep 30 "Waitng for $router_HV to shutdown ................" 

Write-Host "Creating new VSwitch $VSwitch" -ForegroundColor Yellow 
If ((Get-VMSwitch -Name $VSwitch -ErrorAction SilentlyContinue) -eq $null) {
    $vmSwitch = New-VMSwitch -name $VSwitch -SwitchType Private 
}

Write-Host "Creating new VSwitch $VSwitch_Internet" -ForegroundColor Yellow 
If ((Get-VMSwitch -Name $VSwitch_Internet -ErrorAction SilentlyContinue) -eq $null) {
    $vmSwitch_Internet = New-VMSwitch -name $VSwitch_Internet -SwitchType Private
}

Write-Host "Creating new VSwitch $VSwitch_Internet2" -ForegroundColor Yellow 
If ((Get-VMSwitch -Name $VSwitch_Internet2 -ErrorAction SilentlyContinue) -eq $null) {
    $vmSwitch_Internet2 = New-VMSwitch -name $VSwitch_Internet2 -SwitchType Private 
}

Write-Host "Creating new VSwitch $VSwitch_CYL2" -ForegroundColor Yellow 
If ((Get-VMSwitch -Name $VSwitch_CYL2 -ErrorAction SilentlyContinue) -eq $null) {
    $vmSwitch_CYL2 = New-VMSwitch -name $VSwitch_CYL2 -SwitchType Private 
}

Write-Host "Creating new VSwitch $VSwitch_DMZ" -ForegroundColor Yellow 
If ((Get-VMSwitch -Name $VSwitch_DMZ -ErrorAction SilentlyContinue) -eq $null) {
    $vmSwitch_DMZ = New-VMSwitch -name $VSwitch_DMZ -SwitchType Private 
}

Write-Host "Creating new VSwitch $VSwitch_DMZ2" -ForegroundColor Yellow 
If ((Get-VMSwitch -Name $VSwitch_DMZ2 -ErrorAction SilentlyContinue) -eq $null) {
    $vmSwitch_DMZ2 = New-VMSwitch -name $VSwitch_DMZ2 -SwitchType Private 
}

Write-Host "Changing MAC Address on the 1st Network Adapter on $router_HV" -ForegroundColor Yellow
$vmnetadapter = Get-VMNetworkAdapter -VMName $router_hv | Set-VMNetworkAdapter -StaticMacAddress '00:00:00:00:00:01'


Write-Host "Adding a 2nd Network Adapter to $router_HV" -ForegroundColor Yellow 
$vmnetAdapter = Add-VMNetworkAdapter -VMName $router_HV -SwitchName $VSwitch -StaticMacAddress '00:00:00:00:00:02'

Write-Host "Adding a 3nd Network Adapter to $router_HV" -ForegroundColor Yellow 
$vmnetAdapter_Internet = Add-VMNetworkAdapter -VMName $router_HV -SwitchName $VSwitch_Internet -StaticMacAddress '00:00:00:00:00:03'

Write-Host "Adding a 4th Network Adapter to $router_HV" -ForegroundColor Yellow 
$vmnetAdapter_Internet = Add-VMNetworkAdapter -VMName $router_HV -SwitchName $VSwitch_Internet -StaticMacAddress '00:00:00:00:00:04'

Write-Host "Adding a 5th Network Adapter to $router_HV" -ForegroundColor Yellow 
$vmnetAdapter_CYL2 = Add-VMNetworkAdapter -VMName $router_HV -SwitchName $VSwitch_CYL2 -StaticMacAddress '00:00:00:00:00:05'

Write-Host "Adding a 6th Network Adapter to $router_HV" -ForegroundColor Yellow 
$vmnetAdapter_DMZ = Add-VMNetworkAdapter -VMName $router_HV -SwitchName $VSwitch_DMZ -StaticMacAddress '00:00:00:00:00:06'

Write-Host "Adding a 7th Network Adapter to $router_HV" -ForegroundColor Yellow 
$vmnetAdapter_Internet2 = Add-VMNetworkAdapter -VMName $router_HV -SwitchName $VSwitch_Internet2 -StaticMacAddress '00:00:00:00:00:07'

Write-Host "Adding a 8th Network Adapter to $router_HV" -ForegroundColor Yellow 
$vmnetAdapter_InternetDHPCPRelay2 = Add-VMNetworkAdapter -VMName $router_HV -SwitchName $VSwitch_Internet2 -StaticMacAddress '00:00:00:00:00:08'

#Write-Host "Adding a 9th Network Adapter to $router_HV" -ForegroundColor Yellow 
#$vmnetAdapter_DMZ2 = Add-VMNetworkAdapter -VMName $router_HV -SwitchName $VSwitch_DMZ2 -IsLegacy $true -StaticMacAddress '00:00:00:00:00:09'

Write-Host "Starting $Router_HV" -ForegroundColor Yellow 
$vm = Start-VM -Name $router_HV 
Wait-Sleep 30 "Waiting to start......Be Patient" 


# Change the Default GW Settings on the 1st NIC of $VMName 

Write-Host "Ethernet on $VMName does not require a Default GW, Removing it..." -ForegroundColor Yellow 
$nicinfo =  Invoke-Command -VMName $VMName -Credential $DomainCred  {Get-WmiObject win32_networkadapter | Where-Object {$_.MacAddress -eq '00:00:00:00:00:01'} | remove-netroute -destinationprefix 0.0.0.0/0 -ErrorAction SilentlyContinue -confirm:$false}
Write-Host "Renaming 1st NIC to CorpNet" -ForegroundColor Yellow
$nicInfo = Invoke-Command -VMName $VMName -Credential $DomainCred  {Get-NetAdapter| Where-Object {$_.MacAddress -eq '00-00-00-00-00-01'} | Rename-NetAdapter -NewName "CorpNet"}
Write-Host "Renaming 2st NIC to DRNet" -ForegroundColor Yellow
$nicInfo = Invoke-Command -VMName $VMName -Credential $DomainCred  {Get-NetAdapter| Where-Object {$_.MacAddress -eq '00-00-00-00-00-02'} | Rename-NetAdapter -NewName "DRNet"}
Write-Host "Renaming 3rd NIC to Internet" -ForegroundColor Yellow
$nicInfo = Invoke-Command -VMName $VMName -Credential $DomainCred  {Get-NetAdapter| Where-Object {$_.MacAddress -eq '00-00-00-00-00-03'} | Rename-NetAdapter -NewName "Internet"}
Write-Host "Renaming 4th NIC to DHCP Relay" -ForegroundColor Yellow
$nicInfo = Invoke-Command -VMName $VMName -Credential $DomainCred  {Get-NetAdapter| Where-Object {$_.MacAddress -eq '00-00-00-00-00-04'} | Rename-NetAdapter -NewName "DHCPRelay"}
Write-Host "Renaming 5st NIC to FSWSite" -ForegroundColor Yellow
$nicInfo = Invoke-Command -VMName $VMName -Credential $DomainCred  {Get-NetAdapter| Where-Object {$_.MacAddress -eq '00-00-00-00-00-05'} | Rename-NetAdapter -NewName "FSWSite"}
Write-Host "Renaming 6th NIC to DMZ" -ForegroundColor Yellow
$nicInfo = Invoke-Command -VMName $VMName -Credential $DomainCred  {Get-NetAdapter| Where-Object {$_.MacAddress -eq '00-00-00-00-00-06'} | Rename-NetAdapter -NewName "DMZ"}
Write-Host "Renaming 7th NIC to Internet2" -ForegroundColor Yellow
$nicInfo = Invoke-Command -VMName $VMName -Credential $DomainCred  {Get-NetAdapter| Where-Object {$_.MacAddress -eq '00-00-00-00-00-07'} | Rename-NetAdapter -NewName "Internet2"}
Write-Host "Renaming 8th NIC to DHCP Relay 2" -ForegroundColor Yellow
$nicInfo = Invoke-Command -VMName $VMName -Credential $DomainCred  {Get-NetAdapter| Where-Object {$_.MacAddress -eq '00-00-00-00-00-08'} | Rename-NetAdapter -NewName "DHCPRelay2"}
Write-Host "Renaming 9th NIC to DMZ2" -ForegroundColor Yellow
$nicInfo = Invoke-Command -VMName $VMName -Credential $DomainCred  {Get-NetAdapter| Where-Object {$_.MacAddress -eq '00-00-00-00-00-09'} | Rename-NetAdapter -NewName "DMZ2"}

# Change the IP Address of the newly added 2nd NIC in $VMName 
Write-Host "Adding an IP Address of $IPAddress to $VMName's 'DRNet' Adapter for Internet Simulation" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $IPAddress  { Param($IPAddress) New-NetIpaddress -InterfaceAlias "DRNet" -IPAddress $IPAddress -PrefixLength 24} 
Write-Host "Setting Primary DNS on $VMName for Ethernet to pointing to $dc" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $dnsServerIP  { Param($dnsServerIP) Set-DnsClientServerAddress -Interfacealias "DRNet" -ServerAddresses $dnsServerIP} 
Write-Host "DRNet on $VMName does not require a Default GW, Removing it..." -ForegroundColor Yellow 
$nicinfo =  Invoke-Command -VMName $VMName -Credential $DomainCred  {remove-netroute -interfacealias "DRNet" -destinationprefix 0.0.0.0/0 -ErrorAction SilentlyContinue -confirm:$false}

# Change the IP Address of the newly added 3nd NIC in $VMName 
Write-Host "Adding an IP Address of $IPAddress_Internet to $VMName's 'Internet' Adapter for Internet Simulation" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $IPAddress_Internet  { Param($IPAddress_Internet) New-NetIpaddress -InterfaceAlias "Internet" -IPAddress $IPAddress_Internet -PrefixLength 24} 
Write-Host "Setting Primary DNS on $VMName for Ethernet to pointing to $dc" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $dnsServerIP  { Param($dnsServerIP) Set-DnsClientServerAddress -Interfacealias "Internet" -ServerAddresses $dnsServerIP} 
Write-Host "Internet on $VMName does not require a Default GW, Removing it..." -ForegroundColor Yellow 
$nicinfo =  Invoke-Command -VMName $VMName -Credential $DomainCred  {remove-netroute -interfacealias "Internet" -destinationprefix 0.0.0.0/0 -ErrorAction SilentlyContinue -confirm:$false}

# Change the IP Address of the newly added 4th NIC in $VMName 
Write-Host "Adding an IP Address of $IPAddress_DHCPRelay to $VMName's 'DHCPRelay' Adapter for Internet Simulation" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $IPAddress_DHCPRelay  { Param($IPAddress_DHCPRelay) New-NetIpaddress -InterfaceAlias "DHCPRelay" -IPAddress $IPAddress_DHCPRelay -PrefixLength 24} 
Write-Host "Setting Primary DNS on $VMName for Ethernet to pointing to $dc" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $dnsServerIP  { Param($dnsServerIP) Set-DnsClientServerAddress -Interfacealias "DHCPRelay" -ServerAddresses $dnsServerIP} 
Write-Host "DHCPRelay on $VMName does not require a Default GW, Removing it..." -ForegroundColor Yellow 
$nicinfo =  Invoke-Command -VMName $VMName -Credential $DomainCred  {remove-netroute -interfacealias "DHCPRelay" -destinationprefix 0.0.0.0/0 -ErrorAction SilentlyContinue -confirm:$false}

# Change the IP Address of the newly added 5th NIC in $VMName 
Write-Host "Adding an IP Address of $IPAddress_CYL2 to $VMName's 'FSWSite' Adapter for Internet Simulation" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $IPAddress_CYL2  { Param($IPAddress_CYL2) New-NetIpaddress -InterfaceAlias "FSWSite" -IPAddress $IPAddress_CYL2 -PrefixLength 24} 
Write-Host "Setting Primary DNS on $VMName for Ethernet to pointing to $dc" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $dnsServerIP  { Param($dnsServerIP) Set-DnsClientServerAddress -Interfacealias "FSWSite" -ServerAddresses $dnsServerIP} 
Write-Host "FSWSite on $VMName does not require a Default GW, Removing it..." -ForegroundColor Yellow 
$nicinfo =  Invoke-Command -VMName $VMName -Credential $DomainCred  {remove-netroute -interfacealias "FSWSite" -destinationprefix 0.0.0.0/0 -ErrorAction SilentlyContinue -confirm:$false}

# Change the IP Address of the newly added 6th NIC in $VMName 
Write-Host "Adding an IP Address of $IPAddress_DMZ to $VMName's 'DMZ' Adapter for Internet Simulation" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $IPAddress_DMZ  { Param($IPAddress_DMZ) New-NetIpaddress -InterfaceAlias "DMZ" -IPAddress $IPAddress_DMZ -PrefixLength 24} 
Write-Host "Setting Primary DNS on $VMName for Ethernet to pointing to $dc" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $dnsServerIP  { Param($dnsServerIP) Set-DnsClientServerAddress -Interfacealias "DMZ" -ServerAddresses $dnsServerIP} 
Write-Host "DMZ on $VMName does not require a Default GW, Removing it..." -ForegroundColor Yellow 
$nicinfo =  Invoke-Command -VMName $VMName -Credential $DomainCred  {remove-netroute -interfacealias "DMZ" -destinationprefix 0.0.0.0/0 -ErrorAction SilentlyContinue -confirm:$false}

# Change the IP Address of the newly added 7th NIC in $VMName 
Write-Host "Adding an IP Address of $IPAddress_Internet2 to $VMName's 'Internet2' Adapter for Internet Simulation" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $IPAddress_Internet2  { Param($IPAddress_Internet2) New-NetIpaddress -InterfaceAlias "Internet2" -IPAddress $IPAddress_Internet2 -PrefixLength 24} 
Write-Host "Setting Primary DNS on $VMName for Ethernet to pointing to $dc" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $dnsServerIP  { Param($dnsServerIP) Set-DnsClientServerAddress -Interfacealias "Internet2" -ServerAddresses $dnsServerIP} 
Write-Host "Internet2 on $VMName does not require a Default GW, Removing it..." -ForegroundColor Yellow 
$nicinfo =  Invoke-Command -VMName $VMName -Credential $DomainCred  {remove-netroute -interfacealias "Internet2" -destinationprefix 0.0.0.0/0 -ErrorAction SilentlyContinue -confirm:$false}

# Change the IP Address of the newly added 8th NIC in $VMName 
Write-Host "Adding an IP Address of $IPAddress_DHCPRelay2 to $VMName's 'DHCPRelay2' Adapter for Internet Simulation 2ND Site" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $IPAddress_DHCPRelay2  { Param($IPAddress_DHCPRelay2) New-NetIpaddress -InterfaceAlias "DHCPRelay2" -IPAddress $IPAddress_DHCPRelay2 -PrefixLength 24} 
Write-Host "Setting Primary DNS on $VMName for Ethernet to pointing to $dc" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -VMName $VMName -Credential $DomainCred -ArgumentList $dnsServerIP  { Param($dnsServerIP) Set-DnsClientServerAddress -Interfacealias "DHCPRelay2" -ServerAddresses $dnsServerIP} 
Write-Host "DHCPRelay2 on $VMName does not require a Default GW, Removing it..." -ForegroundColor Yellow 
$nicinfo =  Invoke-Command -VMName $VMName -Credential $DomainCred  {remove-netroute -interfacealias "DHCPRelay2" -destinationprefix 0.0.0.0/0 -ErrorAction SilentlyContinue -confirm:$false}
<#>
Can't do this as we can only add 8 nics
 Change the IP Address of the newly added 9th NIC in $Router 
Write-Host "Adding an IP Address of $IPAddress_DMZ2 to $Router's 'DMZ2' Adapter for DMZ Simulation 2ND Site" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -ComputerName $router -Credential $Cred -ArgumentList $IPAddress_DMZ2 -ScriptBlock { Param($IPAddress_DMZ2) New-NetIpaddress -InterfaceAlias "DMZ2" -IPAddress $IPAddress_DMZ2 -PrefixLength 24} 
Write-Host "Setting Primary DNS on $router for Ethernet to pointing to $dc" -ForegroundColor Yellow 
$nicinfo = Invoke-Command -ComputerName $router -Credential $Cred -ArgumentList $dnsServerIP -ScriptBlock { Param($dnsServerIP) Set-DnsClientServerAddress -Interfacealias "DMZ2" -ServerAddresses $dnsServerIP} 
Write-Host "DMZ2 on $router does not require a Default GW, Removing it..." -ForegroundColor Yellow 
$nicinfo =  Invoke-Command -ComputerName $router -Credential $Cred -ScriptBlock {remove-netroute -interfacealias "DMZ2" -destinationprefix 0.0.0.0/0 -ErrorAction SilentlyContinue -confirm:$false}
</#>
# Configure the DHCP Relay Agent on the Router
Write-Host "Installing RRAS on $Router for NAT Routing and DHCP Relay...." -ForegroundColor Yellow 
#Install-WindowsFeature -Name RemoteAccess,Routing,RSAT-RemoteAccess-Mgmt -Credential $Cred -ComputerName $Router  | Out-Null
Invoke-Command -VMName $VMName -Credential $DomainCred {Install-WindowsFeature -Name RemoteAccess,Routing,RSAT-RemoteAccess -IncludeManagementTools} 
Invoke-Command -VMName $VMName -Credential $DomainCred { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "ras set conf ENABLED" }

Restart-DemoVM $VMName
Wait-PSDirect $VMName
Write-Host "Configuring RRAS Startup Type to Automatic" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred -{ get-service ramgm* | Set-Service -StartupType Automatic } 
Write-Host "Starting RRAS Service" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred { Start-Service -Name Ramgm* } 
Write-Host "Installing RRAS DHCP Relay Component" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip relay install" } 
Write-Host "Configuring DHCP Relay IP Address with $dhcpServerIP"
#Need to clean this up
Invoke-Command -VMname $VMName -Credential $DomainCred {  Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip relay add dhcpserver 172.16.200.3" } 
rite-Host "Adding DRNET to DHCP Relay Configuration" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip relay add interface ""DRNet""" }
Write-Host "Adding Internet 1 Site's DHCP Relay" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip relay add interface ""DHCPRelay""" }
Write-Host "Adding File Share Witness Site's DHCP Relay" -ForegroundColor Yellow
Invoke-Command -VMname $VMName -Credential $DomainCred { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip relay add interface ""FSWSite""" }
Write-Host "Adding DMZ Site's DHCP Relay" -ForegroundColor Yellow
Invoke-Command -VMname $VMName -Credential $DomainCred { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip relay add interface ""DMZ""" }
#Write-Host "Adding DMZ2 Site's DHCP Relay" -ForegroundColor Yellow
#Invoke-Command -VMName $VMName -Credential $DomainCred { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip relay add interface ""DMZ2""" }
Write-Host "Adding DHCPRelay2 Site's DHCP Relay" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip relay add interface ""DHCPRelay2""" }

# Configure NAT for Direct Access
#Nat Rules need to be adjusted per your lab.   This will configure some just to prove we can set them for now.
Write-Host "Configuring NAT Device on Internet Adapter also Configuring NAT Rules to DA01 for Direct Access ...." -ForegroundColor Yellow 
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat install" } 
Write-Host "Adding DRNET Adapter to Private NAT" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add interface ""DRNET""" }
Write-Host "Adding FSW Adapter to Private NAT" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add interface ""FSWSite""" }
Write-Host "Adding DMZ Adapter to Private NAT" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add interface ""DMZ""" }
Write-Host "Adding CorpNet Adapter Private NAT" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add interface ""CorpNet""" }
#Write-Host "Adding DMZ2 Adapter Private NAT" -ForegroundColor Yellow
#Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add interface ""DMZ2""" }
Write-Host "Adding Internet Adapter to Public Full NAT" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add interface ""Internet"" full" }
Write-Host "Creating NAT Rule for 3389 to $DC" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add portmapping ""Internet"" tcp 0.0.0.0 3389 192.168.1.200 3389" }
Write-Host "Creating NAT Rule for 443 to the Direct Access Server" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add portmapping ""Internet"" tcp 0.0.0.0 443 192.168.1.219 443" }
Write-Host "Creating NAT Rule for 80 to the External PKI Server CRL Website" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add portmapping ""Internet"" tcp 0.0.0.0 80 192.168.1.220 80" }
Write-Host "Adding Internet2 Adapter to Public Full NAT" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add interface ""Internet2"" full" }
Write-Host "Creating NAT Rule for 3389 to DC02" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add portmapping ""Internet2"" tcp 0.0.0.0 3389 192.168.2.210 3389" }
Write-Host "Creating NAT Rule for 443 to 2nd Direct Access Server at other Site" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add portmapping ""Internet2"" tcp 0.0.0.0 443 192.168.2.219 443" }
Write-Host "Creating NAT Rule for 80 to the 2nd External PKI Server CRL Website" -ForegroundColor Yellow
Invoke-Command -VMName $VMName -Credential $DomainCred  { Start-Process -Wait:$true -FilePath "netsh" -ArgumentList "routing ip nat add portmapping ""Internet2"" tcp 0.0.0.0 80 192.168.2.220 80" }
Write-Host "Creating a DHCP Scope for the branches on the DHCP Server ($DHCPServer)" -ForegroundColor Yellow
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {add-dhcpserverv4scope -Name "192.168.2.100-150" -startrange 192.168.2.100 -endrange 192.168.2.150 -subnetmask 255.255.255.0}
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {set-dhcpserverv4optionvalue -ScopeId "192.168.2.0" -DnsDomain "MVPDays.com" -DnsServer 192.168.1.200 -Router 192.168.2.210} 
Wait-Sleep 5

Write-Host "Creating a DHCP Scope for the DMZ on the DHCP Server ($DHCPServer)" -ForegroundColor Yellow
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {add-dhcpserverv4scope -Name "172.16.100.100-150" -startrange 172.16.100.100 -endrange 172.16.100.150 -subnetmask 255.255.255.0}
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {set-dhcpserverv4optionvalue -ScopeId "172.16.100.0" -DnsDomain "MVPDays.com" -DnsServer 192.168.1.200 -Router 172.16.100.210} 
Wait-Sleep 5

Write-Host "Creating a DHCP Scope for the DMZ2 on the DHCP Server ($DHCPServer)" -ForegroundColor Yellow
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {add-dhcpserverv4scope -Name "172.16.200.101-150" -startrange 172.16.201.100 -endrange 172.16.201.150 -subnetmask 255.255.255.0}
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {set-dhcpserverv4optionvalue -ScopeId "172.16.201.0" -DnsDomain "MVPDays.com" -DnsServer 192.168.2.200 -Router 172.16.201.210 -force} 
Wait-Sleep 5

Write-Host "Creating a DHCP Scope for the Internet Simulation on the DHCP Server ($DHCPServer)" -ForegroundColor Yellow
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {add-dhcpserverv4scope -Name "1.1.1.100-150" -startrange 1.1.1.100 -endrange 1.1.1.150 -subnetmask 255.255.255.0}
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {set-dhcpserverv4optionvalue -ScopeId "1.1.1.0" -DnsDomain "isp.net" -DnsServer 1.1.1.3 -Router 1.1.1.1 -force} 
Wait-Sleep 5

Write-Host "Creating a DHCP Scope for the Internet Simulation on the DHCP Server ($DHCPServer)" -ForegroundColor Yellow
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {add-dhcpserverv4scope -Name "2.2.2.100-150" -startrange 2.2.2.100 -endrange 2.2.2.150 -subnetmask 255.255.255.0}
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {set-dhcpserverv4optionvalue -ScopeId "2.2.2.0" -DnsDomain "isp.net" -DnsServer 2.2.2.3 -Router 2.2.2.1 -force} 
Wait-Sleep 5

Write-Host "Creating a DHCP Scope for the $Vswitch_CYL2 on the DHCP Server ($DHCPServer)" -ForegroundColor Yellow
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {add-dhcpserverv4scope -Name "192.168.3.100-150" -startrange 192.168.3.100 -endrange 192.168.3.150 -subnetmask 255.255.255.0}
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {set-dhcpserverv4optionvalue -ScopeId "192.168.3.0" -DnsDomain "MVPDays.com" -DnsServer 192.168.1.200 -Router 192.168.3.210} 
Wait-Sleep 5

Write-Host "Modifying Default Gateway on Default DHCP Scope on DC01 to use 192.168.1.210 as the DG ($DHCPServer)" -ForegroundColor Yellow
Invoke-Command -VMname $DHCPServer -Credential $DomainCred  {set-dhcpserverv4optionvalue -ScopeId "192.168.1.0" -DnsDomain "MVPDays.com" -DnsServer 192.168.1.200 -Router 192.168.1.210} 
Wait-Sleep 5

    
}

Function Wait-Sleep {
	param (
		[int]$sleepSeconds = 60,
		[string]$title = "... Waiting for $sleepSeconds Seconds... Be Patient",
		[string]$titleColor = "Yellow"
	)
	Write-Host -ForegroundColor $titleColor $title
	for ($sleep = 1; $sleep -le $sleepSeconds; $sleep++ ) {
		Write-Progress -ParentId -1 -Id 42 -Activity "Sleeping for $sleepSeconds seconds" -Status "Slept for $sleep Seconds:" -percentcomplete (($sleep / $sleepSeconds) * 100)
		Start-Sleep 1
	}
    Write-Progress -Completed -Id 42 -Activity "Done Sleeping"
    }
    

function Restart-DemoVM
{
     param
     (
         [string]
         $VMName
     )

    Write-Log $VMName 'Rebooting'
    stop-vm $VMName
    start-vm $VMName
}

function Confirm-Path
{
    param
    (
        [string] $path
    )
    if (!(Test-Path $path)) 
    {
        $null = mkdir $path
    }
}

function Write-Log 
{
    param
    (
        [string]$systemName,
        [string]$message
    )

    Write-Host -Object (Get-Date).ToShortTimeString() -ForegroundColor Cyan -NoNewline
    Write-Host -Object ' - [' -ForegroundColor White -NoNewline
    Write-Host -Object $systemName -ForegroundColor Yellow -NoNewline
    Write-Host -Object "]::$($message)" -ForegroundColor White
}

function Clear-File
{
    param
    (
        [string] $file
    )
    
    if (Test-Path $file) 
    {
        $null = Remove-Item $file -Recurse
    }
}

function Get-UnattendChunk 
{
    param
    (
        [string] $pass, 
        [string] $component, 
        [xml] $unattend
    ) 
    
    return $unattend.unattend.settings |
    Where-Object -Property pass -EQ -Value $pass `
    |
    Select-Object -ExpandProperty component `
    |
    Where-Object -Property name -EQ -Value $component
}

function New-UnattendFile 
{
    param
    (
        [string] $filePath
    ) 

    # Reload template - clone is necessary as PowerShell thinks this is a "complex" object
    $unattend = $unattendSource.Clone()
     
    # Customize unattend XML
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.RegisteredOrganization = 'Azure Sea Class Covert Trial' #TR-Egg
    }
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.RegisteredOwner = 'Thomas Rayner - @MrThomasRayner - workingsysadmin.com' #TR-Egg
    }
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.TimeZone = $Timezone
    }
    Get-UnattendChunk 'oobeSystem' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.UserAccounts.AdministratorPassword.Value = $adminPassword
    }
    Get-UnattendChunk 'specialize' 'Microsoft-Windows-Shell-Setup' $unattend | ForEach-Object -Process {
        $_.ProductKey = $WindowsKey
    }

    Clear-File $filePath
    $unattend.Save($filePath)
}

Function Initialize-BaseImage 
{
    Mount-DiskImage $ServerISO
    $DVDDriveLetter = (Get-DiskImage $ServerISO | Get-Volume).DriveLetter
    Copy-Item -Path "$($DVDDriveLetter):\NanoServer\NanoServerImageGenerator\Convert-WindowsImage.ps1" -Destination "$($WorkingDir)\Convert-WindowsImage.ps1" -Force
    Import-Module -Name "$($DVDDriveLetter):\NanoServer\NanoServerImagegenerator\NanoServerImageGenerator.psm1" -Force
   
    <#>
            if (!(Test-Path "$($BaseVHDPath)\NanoBase.vhdx")) 
            {
            New-NanoServerImage -MediaPath "$($DVDDriveLetter):\" -BasePath $BaseVHDPath -TargetPath "$($BaseVHDPath)\NanoBase.vhdx" -Edition Standard -DeploymentType Guest -Compute -Clustering -AdministratorPassword (ConvertTo-SecureString $adminPassword -AsPlainText -Force)
            }
    </#>

    Copy-Item -Path 'D:\working\Convert-WindowsImage.ps1' -Destination "$($WorkingDir)\Convert-WindowsImage.ps1" -Force
    New-UnattendFile "$BaseVHDPath\unattend.xml"
   
    <#>
            if (!(Test-Path "$($BaseVHDPath)\VMServerBaseCore.vhdx")) 
            {
            . "$WorkingDir\Convert-WindowsImage.ps1" -SourcePath "$($DVDDriveLetter):\sources\install.wim" -VHDPath "$($BaseVHDPath)\VMServerBaseCore.vhdx" `
            -SizeBytes 40GB -VHDFormat VHDX -UnattendPath "$($BaseVHDPath)\unattend.xml" `
            -Edition "ServerDataCenterCore" -VHDPartitionStyle GPT
                     
            }
    </#>
  
    Copy-Item -Path 'D:\working\Convert-WindowsImage.ps1' -Destination "$($WorkingDir)\Convert-WindowsImage.ps1" -Force
    
    if (!(Test-Path -Path "$($BaseVHDPath)\VMServerBase.vhdx")) 
    {
        . "$WorkingDir\Convert-WindowsImage.ps1" -SourcePath "$($DVDDriveLetter):\sources\install.wim" -VHDPath "$($BaseVHDPath)\VMServerBase.vhdx" `
        -SizeBytes 40GB -VHDFormat VHDX -UnattendPath "$($BaseVHDPath)\unattend.xml" `
        -Edition 'ServerDataCenter' -VHDPartitionStyle GPT
    }

    Clear-File "$($BaseVHDPath)\unattend.xml"
    Dismount-DiskImage $ServerISO 
    Clear-File "$($WorkingDir)\Convert-WindowsImage.ps1"
}

function Invoke-DemoVMPrep 
{
    param
    (
        [string] $VMName, 
        [string] $GuestOSName, 
        [switch] $FullServer
    ) 

    Write-Log $VMName 'Removing old VM'
    get-vm $VMName -ErrorAction SilentlyContinue |
    stop-vm -TurnOff -Force -Passthru |
    remove-vm -Force
    Clear-File "$($VMPath)\$($GuestOSName).vhdx"
   
    Write-Log $VMName 'Creating new differencing disk'
    if ($FullServer) 
    {
        $null = New-VHD -Path "$($VMPath)\$($GuestOSName).vhdx" -ParentPath "$($BaseVHDPath)\VMServerBase.vhdx" -Differencing
    }

    else 
    {
        $null = New-VHD -Path "$($VMPath)\$($GuestOSName).vhdx" -ParentPath "$($BaseVHDPath)\VMServerBaseCore.vhdx" -Differencing
    }

    Write-Log $VMName 'Creating virtual machine'
    new-vm -Name $VMName -MemoryStartupBytes 4GB -SwitchName $virtualSwitchName `
    -Generation 2 -Path "$($VMPath)\" | Set-VM -ProcessorCount 2 

    Set-VMFirmware -VMName $VMName -SecureBootTemplate MicrosoftUEFICertificateAuthority
    Set-VMFirmware -Vmname $VMName -EnableSecureBoot off
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName).vhdx" -ControllerType SCSI
    Write-Log $VMName 'Starting virtual machine'
    Enable-VMIntegrationService -Name 'Guest Service Interface' -VMName $VMName
    start-vm $VMName
}

function Create-DemoVM 
{
    param
    (
        [string] $VMName, 
        [string] $GuestOSName, 
        [string] $IPNumber = '0'
    ) 
  
    Wait-PSDirect $VMName -cred $localCred

    Invoke-Command -VMName $VMName -Credential $localCred {
        param($IPNumber, $GuestOSName,  $VMName, $domainName, $Subnet)
        if ($IPNumber -ne '0') 
        {
            Write-Output -InputObject "[$($VMName)]:: Setting IP Address to $($Subnet)$($IPNumber)"
            $null = New-NetIPAddress -IPAddress "$($Subnet)$($IPNumber)" -InterfaceAlias 'Ethernet' -PrefixLength 24
            Write-Output -InputObject "[$($VMName)]:: Setting DNS Address"
            Get-DnsClientServerAddress | ForEach-Object -Process {
                Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses "$($Subnet)1"
            }
        }
        Write-Output -InputObject "[$($VMName)]:: Renaming OS to `"$($GuestOSName)`""
        Rename-Computer -NewName $GuestOSName
        Write-Output -InputObject "[$($VMName)]:: Configuring WSMAN Trusted hosts"
        Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "*.$($domainName)" -Force
        Set-Item WSMan:\localhost\client\trustedhosts "$($Subnet)*" -Force -concatenate
        Enable-WSManCredSSP -Role Client -DelegateComputer "*.$($domainName)" -Force
    } -ArgumentList $IPNumber, $GuestOSName, $VMName, $domainName, $Subnet

    Restart-DemoVM $VMName
    
    Wait-PSDirect $VMName -cred $localCred
}
function Invoke-NodeStorageBuild 
{
    param($VMName, $GuestOSName)

    Create-DemoVM $VMName $GuestOSName
    Clear-File "$($VMPath)\$($GuestOSName) - Data 1.vhdx"
    Clear-File "$($VMPath)\$($GuestOSName) - Data 2.vhdx"
    Get-VM $VMName | Stop-VM 
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    new-vhd -Path "$($VMPath)\$($GuestOSName) - Data 1.vhdx" -Dynamic -SizeBytes 200GB 
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - Data 1.vhdx" -ControllerType SCSI
    new-vhd -Path "$($VMPath)\$($GuestOSName) - Data 2.vhdx" -Dynamic -SizeBytes 200GB
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - Data 2.vhdx" -ControllerType SCSI
    Set-VMProcessor -VMName $VMName -Count 2 -ExposeVirtualizationExtensions $true
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -AllowTeaming On
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing on
    Start-VM $VMName
    Wait-PSDirect $VMName -cred $localCred

    Invoke-Command -VMName $VMName -Credential $localCred {
        param($VMName, $domainCred, $domainName)
        Write-Output -InputObject "[$($VMName)]:: Installing Clustering"
        $null = Install-WindowsFeature -Name File-Services, Failover-Clustering, Hyper-V -IncludeManagementTools
        Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
        while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
        {
            Start-Sleep -Seconds 1
        }
        do 
        {
            Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
        }
        until ($?)
    } -ArgumentList $VMName, $domainCred, $domainName

    Invoke-Command -VMName $VMName -Credential $localCred {
        Rename-NetAdapter -Name 'Ethernet' -NewName 'LOM-P0'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Rename-NetAdapter -Name 'Ethernet 2' -NewName 'LOM-P1'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Rename-NetAdapter -Name 'Ethernet 3' -NewName 'Riser-P0'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Get-NetAdapter -Name 'Ethernet 5' | Rename-NetAdapter -NewName 'Riser-P1'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        New-NetLbfoTeam -Name HyperVTeam -TeamMembers 'LOM-P0' -verbose -confirm:$false
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Add-NetLbfoTeamMember 'LOM-P1' -team HyperVTeam -confirm:$false
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        New-NetLbfoTeam -Name StorageTeam -TeamMembers 'Riser-P0' -verbose -confirm:$false
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Add-NetLbfoTeamMember 'Riser-P1' -team StorageTeam -confirm:$false
    }

    Restart-DemoVM $VMName
    Wait-PSDirect $VMName -cred $domainCred

    Invoke-Command -VMName $VMName -Credential $domainCred {
        New-VMSwitch -Name 'VSW01' -NetAdapterName 'HyperVTeam' -AllowManagementOS $false
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name ClusterCSV-VLAN204 -Switchname VSW01 -verbose
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name LM-VLAN203 -Switchname VSW01 -verbose
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name Servers-VLAN201 -Switchname VSW01 -verbose
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name MGMT-VLAN200 -Switchname VSW01 -verbose
    }

    Restart-DemoVM $VMName
}

function Invoke-ComputeNodePrep 
{
    param($VMName, $GuestOSName)

    Write-Log $VMName 'Removing old VM'
    get-vm $VMName -ErrorAction SilentlyContinue |
    stop-vm -TurnOff -Force -Passthru |
    remove-vm -Force
    Clear-File "$($VMPath)\$($GuestOSName).vhdx"

    Copy-Item -Path "$($BaseVHDPath)\VMServerBase.vhdx" -Destination "$($VMPath)\$($GuestOSName).vhdx"

    Write-Log $VMName 'Creating virtual machine'
    new-vm -Name $VMName -MemoryStartupBytes 12384MB -SwitchName $virtualSwitchName `
    -Generation 2 -Path "$($VMPath)\$($GuestOSName)"

    Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false
    Set-VMProcessor -VMName $VMName -Count 2 -ExposeVirtualizationExtensions $true
    Set-VMFirmware -VMName $VMName -SecureBootTemplate MicrosoftUEFICertificateAuthority
    Set-VMFirmware -VMName $VMName -EnableSecureBoot off
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName).vhdx" -ControllerType SCSI
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -AllowTeaming On
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing on

    Write-Log $VMName 'Starting virtual machine'
    do 
    {
        start-vm $VMName
    }
    until ($?)
}

function Initialize-ComputeNode 
{
    param($VMName, $GuestOSName)

    Create-DemoVM $VMName $GuestOSName

    Get-VM $VMName | Stop-VM 
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Set-VMProcessor -VMName $VMName -Count 2 -ExposeVirtualizationExtensions $true
    Set-VMMemory -VMName $VMName -StartupBytes 16GB
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -AllowTeaming On
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing on
    Start-VM $VMName
    Wait-PSDirect $VMName -cred $localCred

    Invoke-Command -VMName $VMName -Credential $localCred {
        param($VMName, $domainCred, $domainName)
        Write-Output -InputObject "[$($VMName)]:: Installing Clustering"
        $null = Install-WindowsFeature -Name File-Services, Failover-Clustering, Hyper-V -IncludeManagementTools
        Restart-VM
        Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
        while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
        {
            Start-Sleep -Seconds 1
        }
        do 
        {
            Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
        }
        until ($?)
    } -ArgumentList $VMName, $domainCred, $domainName

    Invoke-Command -VMName $VMName -Credential $localCred {
        Rename-NetAdapter -Name 'Ethernet' -NewName 'LOM-P0'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Rename-NetAdapter -Name 'Ethernet 2' -NewName 'LOM-P1'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Rename-NetAdapter -Name 'Ethernet 3' -NewName 'Riser-P0'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Get-NetAdapter -Name 'Ethernet 5' | Rename-NetAdapter -NewName 'Riser-P1'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        New-NetLbfoTeam -Name HyperVTeam -TeamMembers 'LOM-P0' -verbose -confirm:$false
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Add-NetLbfoTeamMember 'LOM-P1' -team HyperVTeam -confirm:$false
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        New-NetLbfoTeam -Name StorageTeam -TeamMembers 'Riser-P0' -verbose -confirm:$false
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Add-NetLbfoTeamMember 'Riser-P1' -team StorageTeam -confirm:$false
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        PING.EXE localhost -n 10
    }
    Restart-DemoVM $vmanme
    Wait-PSDirect $VMName -cred $domainCred
    Invoke-Command -VMName $VMName -Credential $domainCred {
        New-VMSwitch -Name 'VSW01' -NetAdapterName 'HyperVTeam' -AllowManagementOS $false
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name ClusterCSV-VLAN204 -Switchname VSW01 -verbose
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name LM-VLAN203 -Switchname VSW01 -verbose
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name Servers-VLAN201 -Switchname VSW01 -verbose
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name MGMT-VLAN200 -Switchname VSW01 -verbose
    }

    Restart-DemoVM $VMName
}

function Invoke-HCIBuild 
{
    param($VMName, $GuestOSName)

    Create-DemoVM $VMName $GuestOSName
    Clear-File "$($VMPath)\$($GuestOSName) - Data 1.vhdx"
    Clear-File "$($VMPath)\$($GuestOSName) - Data 2.vhdx"
    Get-VM $VMName | Stop-VM 
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    new-vhd -Path "$($VMPath)\$($GuestOSName) - Data 1.vhdx" -Dynamic -SizeBytes 200GB 
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - Data 1.vhdx" -ControllerType SCSI
    new-vhd -Path "$($VMPath)\$($GuestOSName) - Data 2.vhdx" -Dynamic -SizeBytes 200GB
    Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - Data 2.vhdx" -ControllerType SCSI
    Set-VMProcessor -VMName $VMName -Count 2 -ExposeVirtualizationExtensions $true
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $virtualSwitchName
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -AllowTeaming On
    Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing on
    Start-VM $VMName
    Wait-PSDirect $VMName -cred $localCred

    Invoke-Command -VMName $VMName -Credential $localCred {
        param($VMName, $domainCred, $domainName)
        Write-Output -InputObject "[$($VMName)]:: Installing Clustering"
        $null = Install-WindowsFeature -Name File-Services, Failover-Clustering, Hyper-V -IncludeManagementTools
        Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
        while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
        {
            Start-Sleep -Seconds 1
        }
        do 
        {
            Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
        }
        until ($?)
    } -ArgumentList $VMName, $domainCred, $domainName

    Invoke-Command -VMName $VMName -Credential $localCred {
        Rename-NetAdapter -Name 'Ethernet' -NewName 'LOM-P0'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Rename-NetAdapter -Name 'Ethernet 2' -NewName 'LOM-P1'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Rename-NetAdapter -Name 'Ethernet 3' -NewName 'Riser-P0'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Get-NetAdapter -Name 'Ethernet 5' | Rename-NetAdapter -NewName 'Riser-P1'
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        New-NetLbfoTeam -Name HyperVTeam -TeamMembers 'LOM-P0' -verbose -confirm:$false
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Add-NetLbfoTeamMember 'LOM-P1' -team HyperVTeam -confirm:$false
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        New-NetLbfoTeam -Name StorageTeam -TeamMembers 'Riser-P0' -verbose -confirm:$false
    }
    Invoke-Command -VMName $VMName -Credential $localCred {
        Add-NetLbfoTeamMember 'Riser-P1' -team StorageTeam -confirm:$false
    }

    Restart-DemoVM $VMName
    Wait-PSDirect $VMName -cred $domainCred

    Invoke-Command -VMName $VMName -Credential $domainCred {
        New-VMSwitch -Name 'VSW01' -NetAdapterName 'HyperVTeam' -AllowManagementOS $false
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name ClusterCSV-VLAN204 -Switchname VSW01 -verbose
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name LM-VLAN203 -Switchname VSW01 -verbose
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name Servers-VLAN201 -Switchname VSW01 -verbose
    }
    Invoke-Command -VMName $VMName -Credential $domainCred {
        Add-VMNetworkAdapter -ManagementOS -Name MGMT-VLAN200 -Switchname VSW01 -verbose
    }

    Restart-DemoVM $VMName
}
#endregion

#region Variable Init
$BaseVHDPath = "$($WorkingDir)\BaseVHDs"
$VMPath = "$($WorkingDir)\VMs"

$localCred = New-Object -TypeName System.Management.Automation.PSCredential `
-ArgumentList 'Administrator', (ConvertTo-SecureString -String $adminPassword -AsPlainText -Force)

$domainCred = New-Object -TypeName System.Management.Automation.PSCredential `
-ArgumentList "$($domainName)\Administrator", (ConvertTo-SecureString -String $domainAdminPassword -AsPlainText -Force)

#$ServerISO = "D:\DCBuild\10586.0.151029-1700.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO"
#$ServerISO = "d:\DCBuild\14393.0.160808-1702.RS1_Release_srvmedia_SERVER_OEMRET_X64FRE_EN-US.ISO"
$ServerISO = 'D:\DCBuild\en_windows_server_2016_technical_preview_5_x64_dvd_8512312.iso'

#$WindowsKey = "2KNJJ-33Y9H-2GXGX-KMQWH-G6H67"
$WindowsKey = '6XBNX-4JQGW-QX6QG-74P76-72V67'

$unattendSource = [xml]@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <servicing></servicing>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>*</ComputerName>
            <ProductKey>2KNJJ-33Y9H-2GXGX-KMQWH-G6H67</ProductKey> 
            <RegisteredOrganization>Organization</RegisteredOrganization>
            <RegisteredOwner>Owner</RegisteredOwner>
            <TimeZone>TZ</TimeZone>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>password</Value>
                    <PlainText>True</PlainText>
                </AdministratorPassword>
            </UserAccounts>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-us</InputLocale>
            <SystemLocale>en-us</SystemLocale>
            <UILanguage>en-us</UILanguage>
            <UILanguageFallback>en-us</UILanguageFallback>
            <UserLocale>en-us</UserLocale>
        </component>
    </settings>
</unattend>
"@
#endregion

Write-Log 'Host' 'Getting started...'

Confirm-Path $BaseVHDPath
Confirm-Path $VMPath
Write-Log 'Host' 'Building Base Images'

if (!(Test-Path -Path "$($BaseVHDPath)\VMServerBase.vhdx")) 
{
    . Initialize-BaseImage
}

if ((Get-VMSwitch | Where-Object -Property name -EQ -Value $virtualSwitchName) -eq $null)
{
    New-VMSwitch -Name $virtualSwitchName -SwitchType Private
}

Invoke-DemoVMPrep 'Domain Controller 1' 'DC1' -FullServer
#Invoke-DemoVMPrep "Container Host" "ConHost"-FullServer
Invoke-DemoVMPrep 'Domain Controller 2' 'DC2'-FullServer
Invoke-DemoVMPrep 'DHCP Server' 'DHCP'-FullServer
Invoke-DemoVMPrep 'Management Console' 'Management' -FullServer
Invoke-DemoVMPrep 'S2DNode1' 'S2DNode1' -FullServer
Invoke-DemoVMPrep 'S2DNode2' 'S2DNode2' -FullServer
Invoke-DemoVMPrep 'S2DNode3' 'S2DNode3' -FullServer
Invoke-DemoVMPrep 'S2DNode4' 'S2DNode4' -FullServer
Invoke-DemoVMPrep '5nine Mgr' '5nine01' -FullServer
Invoke-DemoVMPrep 'Veeam Backup' 'Veeam01' -FullServer
Invoke-DemoVMPrep 'Internet Router' 'Router' -FullServer
Invoke-DemoVMPrep 'Deployment Server' 'MDT01' -FullServer
Invoke-DemoVMPrep 'HCINode1' 'HCINode1' -FullServer
Invoke-DemoVMPrep 'HCINode2' 'HCINode2' -FullServer
Invoke-DemoVMPrep 'HCINode3' 'HCINode3' -FullServer
Invoke-DemoVMPrep 'HCINode4' 'HCINode4' -FullServer
$VMName = 'Domain Controller 1'
$GuestOSName = 'DC1'
$IPNumber = '1'

Create-DemoVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainName, $domainAdminPassword)

    Write-Output -InputObject "[$($VMName)]:: Installing AD"
    $null = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Write-Output -InputObject "[$($VMName)]:: Enabling Active Directory and promoting to domain controller"
    Install-ADDSForest -DomainName $domainName -InstallDNS -NoDNSonNetwork -NoRebootOnCompletion `
    -SafeModeAdministratorPassword (ConvertTo-SecureString -String $domainAdminPassword -AsPlainText -Force) -confirm:$false
} -ArgumentList $VMName, $domainName, $domainAdminPassword

Restart-DemoVM $VMName 

$VMName = 'Veeam Backup'
$GuestOSName = 'Veeam01'
$IPNumber = '250'

Create-DemoVM $VMName $GuestOSName $IPNumber 

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)
    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
} -ArgumentList $VMName, $domainCred, $domainName

Restart-DemoVM $VMName 

$VMName = '5nine MGR'
$GuestOSName = '5nine01'
$IPNumber = '249'

Create-DemoVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)
    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
} -ArgumentList $VMName, $domainCred, $domainName

Restart-DemoVM $VMName 

$VMName = 'Deployment Server'
$GuestOSName = 'MDT01'
$IPNumber = '247'

Create-DemoVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)
    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
} -ArgumentList $VMName, $domainCred, $domainName

Restart-DemoVM $VMName
 
<#>     
        $vmName = "Container Host"
        $GuestOSName =  "ConHost"

        Wait-PSDirect $VMName -cred $localCred

        logger $VMName "Enabling Containers Feature"
        icm -VMName $VMName -Credential $localCred {install-windowsfeature containers} 

        # Reboot
        Restart-DemoVM $VMName; Wait-PSDirect $VMName -cred $localCred

        logger $VMName "Starting background installation of the Container Base OS Image"
        $job = icm -VMName $VMName -Credential $localCred {
        Install-ContainerOSImage C:\CBaseOs_th2_release_10586.0.151029-1700_amd64fre_ServerDatacenterCore_en-us.wim -Force} -asjob
</#>

$VMName = 'DHCP Server'
$GuestOSName = 'DHCP'
$IPNumber = '3'

Create-DemoVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)
    Write-Output -InputObject "[$($VMName)]:: Installing DHCP"
    $null = Install-WindowsFeature DHCP -IncludeManagementTools
    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
    {
        Start-Sleep -Seconds 1
    }
    do 
    {
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
    }
    until ($?)
} -ArgumentList $VMName, $domainCred, $domainName

Restart-DemoVM $VMName
Wait-PSDirect $VMName -cred $domainCred

Invoke-Command -VMName $VMName -Credential $domainCred {
    param($VMName, $domainName, $Subnet, $IPNumber)

    Write-Output -InputObject "[$($VMName)]:: Waiting for name resolution"

    while ((Test-NetConnection -ComputerName $domainName).PingSucceeded -eq $false) 
    {
        Start-Sleep -Seconds 1
    }

    Write-Output -InputObject "[$($VMName)]:: Configuring DHCP Server"    
    Set-DhcpServerv4Binding -BindingState $true -InterfaceAlias Ethernet
    Add-DhcpServerv4Scope -Name 'IPv4 Network' -StartRange "$($Subnet)10" -EndRange "$($Subnet)200" -SubnetMask 255.255.255.0
    Set-DhcpServerv4OptionValue -OptionId 6 -value "$($Subnet)1"
    Add-DhcpServerInDC -DnsName "$($env:computername).$($domainName)"
    foreach($i in 1..99) 
    {
        $mac = '00-b5-5d-fe-f6-' + ($i % 100).ToString('00')
        $ip = $Subnet + '1' + ($i % 100).ToString('00')
        $desc = 'Container ' + $i.ToString()
        $scopeID = $Subnet + '0'
        Add-DhcpServerv4Reservation -IPAddress $ip -ClientId $mac -Description $desc -ScopeId $scopeID
    }
} -ArgumentList $VMName, $domainName, $Subnet, $IPNumber

Restart-DemoVM $VMName

$VMName = 'Internet Router'
$GuestOSName = 'Router'
$IPNumber = '248'

Create-DemoVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)
    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
} -ArgumentList $VMName, $domainCred, $domainName

Restart-DemoVM $VMName
Wait-PSDirect $VMName -cred $domainCred
Build-Internet $VMName 

$VMName = 'Domain Controller 2'
$GuestOSName = 'DC2'
$IPNumber = '2'

Create-DemoVM $VMName $GuestOSName $IPNumber

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)
    Write-Output -InputObject "[$($VMName)]:: Installing AD"
    $null = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
    {
        Start-Sleep -Seconds 1
    }
    do 
    {
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
    }
    until ($?)
} -ArgumentList $VMName, $domainCred, $domainName

Restart-DemoVM $VMName
Wait-PSDirect $VMName -cred $domainCred

Invoke-Command -VMName $VMName -Credential $domainCred {
    param($VMName, $domainName, $domainAdminPassword)

    Write-Output -InputObject "[$($VMName)]:: Waiting for name resolution"

    while ((Test-NetConnection -ComputerName $domainName).PingSucceeded -eq $false) 
    {
        Start-Sleep -Seconds 1
    }

    Write-Output -InputObject "[$($VMName)]:: Enabling Active Directory and promoting to domain controller"
    
    Install-ADDSDomainController -DomainName $domainName -InstallDNS -NoRebootOnCompletion `
    -SafeModeAdministratorPassword (ConvertTo-SecureString -String $domainAdminPassword -AsPlainText -Force) -confirm:$false
} -ArgumentList $VMName, $domainName, $domainAdminPassword

Restart-DemoVM $VMName

$VMName = 'Domain Controller 1'
$GuestOSName = 'DC1'
$IPNumber = '1'

Wait-PSDirect $VMName -cred $domainCred

Invoke-Command -VMName $VMName -Credential $domainCred {
    param($VMName, $password)

    Write-Output -InputObject "[$($VMName)]:: Creating user account for Dave"
    do 
    {
        Start-Sleep -Seconds 5
        New-ADUser `
        -Name 'Dave' `
        -SamAccountName  'Dave' `
        -DisplayName 'Dave' `
        -AccountPassword (ConvertTo-SecureString -String $password -AsPlainText -Force) `
        -ChangePasswordAtLogon $false  `
        -Enabled $true -ea 0
    }
    until ($?)
    Add-ADGroupMember -Identity 'Domain Admins' -Members 'Dave'
} -ArgumentList $VMName, $domainAdminPassword

$VMName = 'Management Console'
$GuestOSName = 'Management'

Create-DemoVM $VMName $GuestOSName

Invoke-Command -VMName $VMName -Credential $localCred {
    param($VMName, $domainCred, $domainName)
    Write-Output -InputObject "[$($VMName)]:: Management tools"
    $null = Install-WindowsFeature RSAT-Clustering, RSAT-Hyper-V-Tools
    Write-Output -InputObject "[$($VMName)]:: Joining domain as `"$($env:computername)`""
    while (!(Test-Connection -ComputerName $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
    {
        Start-Sleep -Seconds 1
    }
    do 
    {
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
    }
    until ($?)
} -ArgumentList $VMName, $domainCred, $domainName

Restart-DemoVM $VMName
Wait-PSDirect $VMName
#Not working just yet
#Stage-Labfiles $VMName

$VMName = 'S2DNode1'
$GuestOSName = 'S2Dnode1'

Invoke-NodeStorageBuild 'S2DNode1' 'S2DNode1' 
Invoke-NodeStorageBuild 'S2DNode2' 'S2DNode2'
Invoke-NodeStorageBuild 'S2DNode3' 'S2DNode3'
Invoke-NodeStorageBuild 'S2DNode4' 'S2DNode4'

Wait-PSDirect 'S2DNode4' -cred $domainCred

Invoke-Command -VMName 'Management Console' -Credential $domainCred {
    param ($domainName)
    do 
    {
        New-Cluster -Name S2DCluster -Node S2DNode1, S2DNode2, S2DNode3, S2DNode4 -NoStorage
    }
    until ($?)
    while (!(Test-Connection -ComputerName "S2DCluster.$($domainName)" -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
    {
        ipconfig.exe /flushdns
        Start-Sleep -Seconds 1
    }
    #Enable-ClusterStorageSpacesDirect -Cluster "S2DCluster.$($domainName)"
    Add-ClusterScaleOutFileServerRole -name S2DFileServer -cluster "S2DCluster.$($domainName)"
} -ArgumentList $domainName

Invoke-Command -VMName 'S2DNode1' -Credential $domainCred {
    param ($domainName)
    #New-StoragePool -StorageSubSystemName "S2DCluster.$($domainName)" -FriendlyName S2DPool -WriteCacheSizeDefault 0 -ProvisioningTypeDefault Fixed -ResiliencySettingNameDefault Mirror -PhysicalDisk (Get-StorageSubSystem  -Name "S2DCluster.$($domainName)" | Get-PhysicalDisk)
    #New-Volume -StoragePoolFriendlyName S2DPool -FriendlyName S2DDisk -PhysicalDiskRedundancy 2 -FileSystem CSVFS_REFS -Size 500GB
    #updated from MSFT TP5 notes

    #New-Cluster -Name CJ-CLU -Node node1,node2,node3 -NoStorage
    Enable-ClusterS2D -CacheMode Disabled -AutoConfig:0 -SkipEligibilityChecks -confirm:$false

    #Create storage pool and set media type to HDD
    New-StoragePool -StorageSubSystemFriendlyName *Cluster* -FriendlyName S2D -ProvisioningTypeDefault Fixed -PhysicalDisk (Get-PhysicalDisk | Where-Object -Property CanPool -EQ -Value $true)

    Get-StorageSubSystem *cluster* |
    Get-PhysicalDisk |
    Where-Object -Property MediaType -EQ -Value 'UnSpecified' |
    Set-PhysicalDisk -MediaType HDD

    #Create storage tiers
    $pool = Get-StoragePool S2D
    New-StorageTier -StoragePoolUniqueID ($pool).UniqueID -FriendlyName Performance -MediaType HDD -ResiliencySettingName Mirror
    New-StorageTier -StoragePoolUniqueID ($pool).UniqueID -FriendlyName Capacity -MediaType HDD -ResiliencySettingName Parity

    #Create a volume
    New-Volume -StoragePoolFriendlyName S2D -FriendlyName Mirror -FileSystem CSVFS_REFS -Size 200GB -PhysicalDiskRedundancy 2
    New-Volume -StoragePoolFriendlyName S2D -FriendlyName Parity1 -FileSystem CSVFS_REFS -Size 200GB -PhysicalDiskRedundancy 1
    Set-FileIntegrity 'C:\ClusterStorage\Volume1' -Enable $false

    mkdir -Path C:\ClusterStorage\Volume1\VHDX
    New-SmbShare -Name VHDX -Path C:\ClusterStorage\Volume1\VHDX -FullAccess "$($domainName)\administrator", "$($domainName)\Dave", "$($domainName)\Management$"
    Set-SmbPathAcl -ShareName VHDX

    mkdir -Path C:\ClusterStorage\Volume1\ClusQuorum
    New-SmbShare -Name ClusQuorum -Path C:\ClusterStorage\Volume1\ClusQuorum -FullAccess "$($domainName)\administrator", "$($domainName)\Dave", "$($domainName)\Management$"
    Set-SmbPathAcl -ShareName ClusQuorum

    mkdir -Path C:\ClusterStorage\Volume1\ClusData
    New-SmbShare -Name ClusData -Path C:\ClusterStorage\Volume1\ClusData -FullAccess "$($domainName)\administrator", "$($domainName)\Dave", "$($domainName)\Management$"
    Set-SmbPathAcl -ShareName ClusData
} -ArgumentList $domainName


Invoke-HCIBuild 'HCINode1' 'HCINode1'
Invoke-HCIBuild 'HCINode2' 'HCINode2'
Invoke-HCIBuild 'HCINode3' 'HCINode3'
Invoke-HCIBuild 'HCINode4' 'HCINode4'
<#>
        $vmName = "Container Host"
        $GuestOSName =  "ConHost"

        icm -VMName $VMName -Credential $localCred {
        new-container "IIS" -ContainerImageName * 
        start-container "IIS"
        icm -ContainerName "IIS" -RunAsAdministrator {install-windowsfeature web-server}
        stop-container "IIS"
        New-ContainerImage -ContainerName "IIS" -Name "IIS" -Publisher "Armstrong" -Version 1.0
        Remove-Container -Name "IIS" -Force
        New-NetFirewallRule -DisplayName "Allow inbound TCP Port 80" -Direction inbound -LocalPort 80 -Protocol TCP -Action Allow}
        icm -VMName $VMName -Credential $localCred {& cmd /c "C:\windows\system32\Sysprep\sysprep.exe /quiet /generalize /oobe /shutdown /unattend:C:\unattend.xml"}

        logger $VMName "Ready to inject Container Host into Storage Cluster"

        while ((get-vm "Container Host").State -ne "Off") {start-sleep 1}

        remove-vm "Container Host" -force

</#>

<#>
        function Initialize-ComputeNode {

        param
        (
        [string] $VMName, 
        [string] $GuestOSName, 
        [string] $IPNumber = "0"
        ); 

        Wait-PSDirect $VMName $localCred

        ping localhost -n 30

        # icm -VMName $VMName -Credential $localCred { Add-WindowsFeature Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart}
        icm -VMName $VMName -Credential $localCred { New-Item -ItemType Directory c:\sym}
        icm -VMName $VMName -Credential $localCred { schtasks.exe /change /disable /tn "\Microsoft\Windows\Defrag\ScheduledDefrag" }
        #icm -VMName $VMName -Credential $localCred { sc config w32time start=delayed-auto }
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"netfx3" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"netfx4" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"qwave" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"snmp" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"wmisnmpprovider" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"server-rsat-snmp" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"telnetclient" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"WindowsStorageManagementService" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"microsoft-hyper-v" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"microsoft-hyper-v-offline" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"microsoft-hyper-v-online" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"rsat-hyper-v-tools-feature" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"microsoft-hyper-v-management-clients" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"microsoft-hyper-v-management-powershell" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"failovercluster-mgmt" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"failovercluster-adminpak" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"failovercluster-powershell" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"failovercluster-automationserver" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"failovercluster-cmdinterface" /all /norestart}
        icm -VMName $VMName -Credential $localCred { dism /online /enable-feature /featurename:"failovercluster-fullserver" /all /norestart}
        icm -VMName $VMName -Credential $localCred { reg add "HKLM\SOFTWARE\GSFW" /v fw_version /t REG_SZ /d "22X" /f}
        icm -VMName $VMName -Credential $localCred { reg add "HKLM\SOFTWARE\GSFW" /v baseboard /t REG_SZ /d "X10DRT-PT" /f }
        icm -VMName $VMName -Credential $localCred { reg add "HKLM\Software\GSFW" /v node_model /t REG_SZ /d "GS-3000-FCN" /f}
        icm -VMName $VMName -Credential $localCred { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v GSFW_VERSION /t REG_SZ /d %VER_STRING% /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v _NT_DEBUG_CACHE_SIZE /t REG_SZ /d "4096000" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v _NT_SYMBOL_PATH /t REG_SZ /d "SRV*c:\\sym*http://msdl.microsoft.com/download/symbols;C:\\windows\\system32;C:\\Program Files\\Gridstore;C:\\Program Files (x86)\\Gridstore;C:\\Program Files\\Gridstore\\NDFS;C:\\Program Files (x86)\\Gridstore\\NDFS;" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v _NT_SYMCACHE_PATH /t REG_SZ /d "c:\\sym" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "PagingFiles" /t REG_MULTI_SZ /d "c:\pagefile.sys 10480 10480" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v "CrashDumpEnabled" /t REG_DWORD /d "2" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v "AutoReboot" /t REG_DWORD /d "1" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v "NMICrashDump" /t REG_DWORD /d "1" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Services\i8042prt\Parameters" /v "CrashOnCtrlScroll" /t REG_DWORD /d "1" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdhid\Parameters" /v "CrashOnCtrlScroll" /t REG_DWORD /d "1" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v verbosestatus /t REG_DWORD /d 1 /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v "fDenyTSConnections" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "UserAuthentication" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "MaxIdleTime" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "MaxConnectionTime" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "MaxDisconnectionTime" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "fResetBroken" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "RemoteAppLogoffTimeLimit" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxIdleTime" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxConnectionTime" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxDisconnectionTime" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fResetBroken" /t REG_DWORD /d "0" /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "RemoteAppLogoffTimeLimit" /t REG_DWORD /d "0" /f}
        # icm -VMName $VMName -Credential $localCred {reg add "HKU\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxIdleTime" /t REG_DWORD /d "0" /f}
        # icm -VMName $VMName -Credential $localCred {reg add "HKU\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxConnectionTime" /t REG_DWORD /d "0" /f}
        # icm -VMName $VMName -Credential $localCred {reg add "HKU\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxDisconnectionTime" /t REG_DWORD /d "0" /f}
        # icm -VMName $VMName -Credential $localCred {reg add "HKU\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fResetBroken" /t REG_DWORD /d "0" /f}
        # icm -VMName $VMName -Credential $localCred {reg add "HKU\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "RemoteAppLogoffTimeLimit" /t REG_DWORD /d "0" /f}

        #::reg add "HKLM\SOFTWARE\Microsoft\WindowsNT\CurrentVersion\SoftwareProtectionPlatform" /v SkipRearm /t REG_DWORD /d 1 /f
        icm -VMName $VMName -Credential $localCred {reg add "HKLM\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration"}
        icm -VMName $VMName -Credential $localCred {reg add "HKCU\Software\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 0x1 /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKCU\Console" /v QuickEdit /t REG_DWORD /d 1 /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" /v AllItemsIconView /t REG_DWORD /d 1 /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" /v StartupPage /t REG_DWORD /d 1 /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 0 /f}
        icm -VMName $VMName -Credential $localCred {reg add "HKCU\Software\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 0x1 /f}
        #::reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\010103000F0000F0010000000F0000F0C967A3643C3AD745950DA7859209176EF5B87C875FA20DF21951640E807D7C24" /v Category /t REG_DWORD /d 0x00000001 /f
        #::reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Group Policy Objects\{84CD9509-EFA7-40A9-A990-CF68B6E4C3C0}Machine\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\010103000F0000F0010000000F0000F0C967A3643C3AD745950DA7859209176EF5B87C875FA20DF21951640E807D7C24" /v Category /t REG_DWORD /d 0x1 /f
        #::reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Group Policy Objects\{864C7F14-370F-4504-A10F-4D03605D73DE}Machine\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\010103000F0000F0010000000F0000F0C967A3643C3AD745950DA7859209176EF5B87C875FA20DF21951640E807D7C24" /v Category /t REG_DWORD /d 0x1 /f

        icm -VMName $VMName -Credential $localCred { netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes}
        icm -VMName $VMName -Credential $localCred {netsh advfirewall firewall set rule name="File and Printer Sharing (Echo Request - ICMPv4-In)" new enable=yes}

        icm -VMName $VMName -Credential $localCred {powercfg -s SCHEME_MIN}
        #::wmic useraccount where "name='admin'" set passwordexpires=false

        #::cscript c:\windows\system32\slmgr.vbs /upk

        #reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 0 /f

                

        Wait-PSDirect $VMName $localCred
        Write-Output "[$($VMName)]:: Renaming OS to `"$($GuestOSName)`""
        icm -VMName $VManme -Credential $localCred{
        Rename-Computer $GuestOSName} -ArgumentList $VMName
        # Reboot
        Restart-DemoVM $VMName; 
        Wait-PSDirect $VMName $localCred
        #  Restart-DemoVM $VMName; 
        Wait-PSDirect $VMName $localCred
        icm -VMName $VMName -Credential $localCred {
        param($VMName, $domainCred, $domainName)
            
        Write-Output "[$($VMName)]:: Joining domain as `"$($env:computername)`""
        while (!(Test-Connection -Computername $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {sleep -seconds 1}
        do {Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue} until ($?)
        } -ArgumentList $VMName, $domainCred, $domainName

        # Reboot
        Restart-DemoVM $VMName; Wait-PSDirect $VMName -cred $domainCred
  
  
  
  
  
  
        #     icm -VMName $VMName -Credential $localCred {Add-Computer -ComputerName $GuestOSName -DomainName mvpdays.com -Credential $domainCred -LocalCredential $localCred -Restart}

        Wait-PSDirect $VMName $localCred

        icm -VMName $VMName -Credential $localCred {enable-wsmancredssp -role server -force}
      
        Wait-PSDirect $VMName $localCred
        #Stage Files for Gridstore Virtual Grid Install
        #There are 2 x Adapters at this time - Ethernet is used for the Hyper-V Virtual Switch and Ethernet2 is free
 
        Copy-VMFile -VM $VMName.ToString() -SourcePath D:\dcbuild\Post-Install\HVHost\001-VirtualGrid\Gridstore.msi -DestinationPath c:\post-install\001-VirtualGrid\gridstore.msi -CreateFullPath -Force -verbose
        Copy-VMFile -VM $VMName.ToString() -SourcePath D:\dcbuild\Post-Install\HVHost\001-VirtualGrid\install-hca.bat -DestinationPath c:\post-install\001-VirtualGrid\install-hca.bat -CreateFullPath -Force -verbose


        #Configure the rest of the Virtual Adapters
        icm -VMName $vmname -Credential $localCred {Rename-NetAdapter -Name "Ethernet" -NewName "LOM-P0"}
        icm -VMName $vmname -Credential $localCred {Rename-NetAdapter -Name "Ethernet 2" -NewName "LOM-P1"}
        icm -VMName $vmname -Credential $localCred {Rename-NetAdapter -Name "Ethernet 3" -NewName "Riser-P0"}
        icm -VMName $vmname -Credential $localCred {Rename-NetAdapter -Name "Ethernet 4" -NewName "Riser-P1"}


        icm -VMName $vmname -Credential $localCred {New-NetLbfoTeam -Name HyperVTeam -TeamMembers "LOM-P0" -verbose}
        icm -VMName $vmname -Credential $localCred {Add-NetLbfoTeammember "LOM-P1" -team HyperVTeam}
        icm -VMName $vmname -Credential $localCred {New-NetLbfoTeam -Name GridTeam -TeamMembers "Riser-P0" -verbose}
        icm -VMName $vmname -Credential $localCred {Add-NetLbfoTeammember "Riser-P1" -team Storage}
        icm -VMName $vmname -Credential $localCred {New-VMSwitch -Name "VSW01" -NetAdapterName "HyperVTeam" -AllowManagementOS $False}
        icm -VMName $vmname -Credential $localCred {Add-VMNetworkAdapter -ManagementOS -Name ClusterCSV-VLAN204 -Switchname VSW01 -verbose}
        icm -VMName $vmname -Credential $localCred {Add-VMNetworkAdapter -ManagementOS -Name LM-VLAN203 -Switchname VSW01 -verbose}
        icm -VMName $vmname -Credential $localCred {Add-VMNetworkAdapter -ManagementOS -Name Servers-VLAN201 -Switchname VSW01 -verbose}
        icm -VMName $vmname -Credential $localCred {Add-VMNetworkAdapter -ManagementOS -Name MGMT-VLAN200 -Switchname VSW01 -verbose}

        #icm -VMName "Hyper-V Node 8" -Credential $localCred {Set-VMNetworkAdapter -ManagementOS -Name "ClusterCSV-VLAN204" -MinimumBandwidthWeight 10}
        #icm -VMName "Hyper-V Node 8" -Credential $localCred {Set-VMNetworkAdapter -ManagementOS -Name "LM-VLAN203" -MinimumBandwidthWeight 60}
        #icm -VMName "Hyper-V Node 8" -Credential $localCred {Set-VMNetworkAdapter -ManagementOS -Name "Servers-VLAN201" -MinimumBandwidthWeight 15}
        #icm -VMName "Hyper-V Node 8" -Credential $localCred {Set-VMNetworkAdapter -ManagementOS -Name "MGMT-VLAN200" -MinimumBandwidthWeight 15}
        #icm -VMName "Hyper-V Node 8" -Credential $localCred {Set-VMNetworkAdaptervlan -ManagementOS -vmnetworkadapterName "VSW01" -Access -VlanId 200}
        #icm -VMName "Hyper-V Node 8" -Credential $localCred {Set-VMNetworkAdaptervlan -ManagementOS -Name "LM-VLAN201" -Access -VlanId 201}
        #icm -VMName "Hyper-V Node 8" -Credential $localCred {Set-VMNetworkAdaptervlan -ManagementOS -Name "MGMT-VLAN200" -Access -VlanId 200}

        Wait-PSDirect $VMName -cred $localCred

        # Set IP address & name
        icm -VMName $VMName -Credential $localCred {
        param($IPNumber, $GuestOSName,  $VMName, $domainName)
        if ($IPNumber -ne "0") {
        Write-Output "[$($VMName)]:: Setting IP Address on GridTeam to 172.16.220.$($IPNumber)"
        New-NetIPAddress -IPAddress "172.16.220.$($IPNumber)" -InterfaceAlias "GridTeam" -PrefixLength 24 | Out-Null
        Write-Output "[$($VMName)]:: Setting IP Address on MGMT - VLAN 200 to 172.16.200.$($IPNumber)"
        New-NetIPAddress -IPAddress "172.16.200.$($IPNumber)" -InterfaceAlias "MGMT-VLAN200" -PrefixLength 24 | Out-Null
        Write-Output "[$($VMName)]:: Setting IP Address on Servers - VLAN 201 to 172.16.201.$($IPNumber)"
        New-NetIPAddress -IPAddress "172.16.201.$($IPNumber)" -InterfaceAlias "Servers-VLAN201" -PrefixLength 24 | Out-Null
        Write-Output "[$($VMName)]:: Setting IP Address on Live Migration - VLAN 203 to 172.16.203.$($IPNumber)"
        New-NetIPAddress -IPAddress "172.16.203.$($IPNumber)" -InterfaceAlias "LM-VLAN203" -PrefixLength 24 | Out-Null
        Write-Output "[$($VMName)]:: Setting IP Address on ClusterCSV - VLAN 204 to 172.16.204.$($IPNumber)"
        New-NetIPAddress -IPAddress "172.16.204.$($IPNumber)" -InterfaceAlias "ClusterCSV-VLAN204" -PrefixLength 24 | Out-Null
        Write-Output "[$($VMName)]:: Setting DNS Address"
        Get-DnsClientServerAddress | %{Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses "$($Subnet)1"}}
        Write-Output "[$($VMName)]:: Configuring WSMAN Trusted hosts"
        Set-Item WSMan:\localhost\Client\TrustedHosts "*.$($domainName)" -Force
        Set-Item WSMan:\localhost\client\trustedhosts "$($Subnet)*" -force -concatenate
        Enable-WSManCredSSP -Role Client -DelegateComputer "*.$($domainName)" -Force
        } -ArgumentList $IPNumber, $GuestOSName, $VMName, $domainName, $Subnet

        #Don't forget to configure the DNS Suffix disable on most adapters

        #playing around with the Gridstore Installations

        icm -VMName $vmname -Credential $localCred {Get-NetAdapter vether* | disable-NetAdapter -Confirm:$False -ErrorAction SilentlyContinue}
        icm -VMName $vmname -Credential $localCred {"c:\post-install\001-virtualgrid\install-hca.bat"}

        ping localhost -n 20

        icm -VMName "$vmname" -Credential $localCred {Get-NetAdapter vether* | Enable-NetAdapter -confirm:$false -ErrorAction SilentlyContinue }
        }
</#>
 
#logger $VMName "Creating standard virtual switch"

Invoke-ComputeNodePrep 'Hyper-V Node 1' 'HVNode1' 
Invoke-ComputeNodePrep 'Hyper-V Node 2' 'HVNode2'
Invoke-ComputeNodePrep 'Hyper-V Node 3' 'HVNode3'
Invoke-ComputeNodePrep 'Hyper-V Node 4' 'HVNode4'
Invoke-ComputeNodePrep 'Hyper-V Node 5' 'HVNode5'
Invoke-ComputeNodePrep 'Hyper-V Node 6' 'HVNode6'
Invoke-ComputeNodePrep 'Hyper-V Node 7' 'HVNode7'
Invoke-ComputeNodePrep 'Hyper-V Node 8' 'HVNode8'

<#>
        icm -VMName "Management Console" -Credential $domainCred {
        param($domainName)
        djoin.exe /provision /domain $domainName /machine "HVNode1" /savefile \\172.16.200.1\c$\HVNode1.txt
        djoin.exe /provision /domain $domainName /machine "HVNode2" /savefile \\172.16.200.1\c$\HVNode2.txt
        djoin.exe /provision /domain $domainName /machine "HVNode3" /savefile \\172.16.200.1\c$\HVNode3.txt
        djoin.exe /provision /domain $domainName /machine "HVNode4" /savefile \\172.16.200.1\c$\HVNode4.txt
        djoin.exe /provision /domain $domainName /machine "HVNode5" /savefile \\172.16.200.1\c$\HVNode5.txt
        djoin.exe /provision /domain $domainName /machine "HVNode6" /savefile \\172.16.200.1\c$\HVNode6.txt
        djoin.exe /provision /domain $domainName /machine "HVNode7" /savefile \\172.16.200.1\c$\HVNode7.txt
        djoin.exe /provision /domain $domainName /machine "HVNode8" /savefile \\172.16.200.1\c$\HVNode8.txt} -ArgumentList $domainName
</#>

Initialize-ComputeNode 'Hyper-V Node 1' 'HVNode1' 
Initialize-ComputeNode 'Hyper-V Node 2' 'HVNode2' 
Initialize-ComputeNode 'Hyper-V Node 3' 'HVNode3' 
Initialize-ComputeNode 'Hyper-V Node 4' 'HVNode4' 
Initialize-ComputeNode 'Hyper-V Node 5' 'HVNode5' 
Initialize-ComputeNode 'Hyper-V Node 6' 'HVNode6' 
Initialize-ComputeNode 'Hyper-V Node 7' 'HVNode7' 
Initialize-ComputeNode 'Hyper-V Node 8' 'HVNode8' 

Wait-PSDirect 'Hyper-V Node 8' -cred $domainCred

Invoke-Command -VMName 'Management Console' -Credential $domainCred {
    param ($domainName)
    do 
    {
        New-Cluster -Name HVCluster -Node HVNode1, HVNode2, HVNode3, HVNode4, HVNode5, HVNode6, HVNode7, HVNode8 -NoStorage
    }
    until ($?)
    while (!(Test-Connection -ComputerName "HVCluster.$($domainName)" -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
    {
        ipconfig.exe /flushdns
        Start-Sleep -Seconds 1
    }
} -ArgumentList $domainName

<#>
        Clear-File "$($VMPath)\ConHost - Diff.vhdx"
        New-VHD -Path "$($VMPath)\ConHost - Diff.vhdx" -ParentPath "$($VMPath)\ConHost.vhdx" -Differencing | Out-Null

        Add-VMHardDiskDrive -VMName "Hyper-V Node 1" -Path "$($VMPath)\ConHost - Diff.vhdx"

        icm -VMName "Hyper-V Node 1" -Credential $domainCred {while ((get-disk).Count -ne 2) {start-sleep 1}
        New-VHD -path "\\s2dfileserver\vhdx\ContainerBase.VHDX" -Dynamic -SourceDisk 1}

        foreach ($i in 1..8) {

        icm -VMName "Hyper-V Node $($i)" -Credential $domainCred {
        param ($k, $domainName, $localCred)
        Set-VMHost -VirtualHardDiskPath "\\S2DFileServer.$($domainName)\VHDX" `
        -VirtualMachinePath "\\S2DFileServer.$($domainName)\VHDX" 

        $j = $k - 1
        do {New-VHD -Path "\\s2dfileserver\vhdx\Container Host $($j).VHDX" -ParentPath "\\s2dfileserver\vhdx\ContainerBase.VHDX" -Differencing -ea 0| Out-Null} until ($?)
        do {new-vm -Name "Container Host $($j)" -MemoryStartupBytes 768MB -SwitchName "Virtual Switch" `
        -VHDPath "\\s2dfileserver\vhdx\Container Host $($j).VHDX" -Generation 2 -ea 0} until ($?)
        Set-VM -name "Container Host $($j)" -ProcessorCount 2
        Get-VMNetworkAdapter -VMName "Container Host $($j)" | Set-VMNetworkAdapter -MacAddressSpoofing on
        start-vm "Container Host $($j)"
        New-VHD -Path "\\s2dfileserver\vhdx\Container Host $($k).VHDX" -ParentPath "\\s2dfileserver\vhdx\ContainerBase.VHDX" -Differencing | Out-Null
        do {new-vm -Name "Container Host $($k)" -MemoryStartupBytes 768MB -SwitchName "Virtual Switch" `
        -VHDPath "\\s2dfileserver\vhdx\Container Host $($k).VHDX" -Generation 2 -ea 0} until ($?)
        Set-VM -Name "Container Host $($k)" -ProcessorCount 2
        Get-VMNetworkAdapter -VMName "Container Host $($k)" | Set-VMNetworkAdapter -MacAddressSpoofing on
        start-vm "Container Host $($k)"
        while ((icm -VMName "Container Host $($k)" -Credential $localCred {"Test"} -ea SilentlyContinue) -ne "Test") {Sleep -Seconds 1}

        icm -VMName "Container Host $($j)" -Credential $localCred {
        param ($containerNo)
        if ((Get-VMSwitch | ? name -eq "Virtual Switch") -eq $null)
        {
        New-VMSwitch -Name "Virtual Switch" -NetAdapterName "Ethernet" -AllowManagementOS $true
        }
        New-Container -Name "IIS$($containerNo-3)" -ContainerImageName "IIS"
        $cnMac = "00-b5-5d-fe-f6-" + (($containerNo-3) % 100).ToString("00")
        Add-ContainerNetworkAdapter -ContainerName "IIS$($containerNo-3)" -SwitchName "Virtual Switch" -StaticMacAddress $cnMac
        start-container "IIS$($containerNo-3)"

        New-Container -Name "IIS$($containerNo-2)" -ContainerImageName "IIS"
        $cnMac = "00-b5-5d-fe-f6-" + (($containerNo-2) % 100).ToString("00")
        Add-ContainerNetworkAdapter -ContainerName "IIS$($containerNo-2)" -SwitchName "Virtual Switch" -StaticMacAddress $cnMac
        # start-container "IIS$($containerNo-2)"

        New-Container -Name "IIS$($containerNo-1)" -ContainerImageName "IIS"
        $cnMac = "00-b5-5d-fe-f6-" + (($containerNo-1) % 100).ToString("00")
        Add-ContainerNetworkAdapter -ContainerName "IIS$($containerNo-1)" -SwitchName "Virtual Switch" -StaticMacAddress $cnMac
        # start-container "IIS$($containerNo-1)"

        New-Container -Name "IIS$($containerNo)" -ContainerImageName "IIS"
        $cnMac = "00-b5-5d-fe-f6-" + (($containerNo) % 100).ToString("00")
        Add-ContainerNetworkAdapter -ContainerName "IIS$($containerNo)" -SwitchName "Virtual Switch" -StaticMacAddress $cnMac
        # start-container "IIS$($containerNo)"
        } -ArgumentList ($j*4)

        icm -VMName "Container Host $($k)" -Credential $localCred {
        param ($containerNo)
        if ((Get-VMSwitch | ? name -eq "Virtual Switch") -eq $null)
        {
        New-VMSwitch -Name "Virtual Switch" -NetAdapterName "Ethernet" -AllowManagementOS $true
        }
        New-Container -Name "IIS$($containerNo-3)" -ContainerImageName "IIS"
        $cnMac = "00-b5-5d-fe-f6-" + (($containerNo-3) % 100).ToString("00")
        Add-ContainerNetworkAdapter -ContainerName "IIS$($containerNo-3)" -SwitchName "Virtual Switch" -StaticMacAddress $cnMac
        start-container "IIS$($containerNo-3)"

        New-Container -Name "IIS$($containerNo-2)" -ContainerImageName "IIS"
        $cnMac = "00-b5-5d-fe-f6-" + (($containerNo-2) % 100).ToString("00")
        Add-ContainerNetworkAdapter -ContainerName "IIS$($containerNo-2)" -SwitchName "Virtual Switch" -StaticMacAddress $cnMac
        # start-container "IIS$($containerNo-2)"

        New-Container -Name "IIS$($containerNo-1)" -ContainerImageName "IIS"
        $cnMac = "00-b5-5d-fe-f6-" + (($containerNo-1) % 100).ToString("00")
        Add-ContainerNetworkAdapter -ContainerName "IIS$($containerNo-1)" -SwitchName "Virtual Switch" -StaticMacAddress $cnMac
        # start-container "IIS$($containerNo-1)"

        New-Container -Name "IIS$($containerNo)" -ContainerImageName "IIS"
        $cnMac = "00-b5-5d-fe-f6-" + (($containerNo) % 100).ToString("00")
        Add-ContainerNetworkAdapter -ContainerName "IIS$($containerNo)" -SwitchName "Virtual Switch" -StaticMacAddress $cnMac
        # start-container "IIS$($containerNo)"
        } -ArgumentList ($k*4)
        } -ArgumentList ($i*2), $domainName, $localCred

        icm -VMName "Management Console" -Credential $domainCred {
        param ($k) 
        $j = $k - 1
        Add-VMToCluster -Cluster HVCluster -VMName "Container Host $($j)"
        Add-VMToCluster -Cluster HVCluster -VMName "Container Host $($k)"} -ArgumentList ($i*2)
        }
</#>




Write-Log 'Done' 'Done!'