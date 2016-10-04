# Parameters
$workingDir = "D:\DCBuild"
$BaseVHDPath = "$($workingDir)\BaseVHDs"
$VMPath = "$($workingDir)\VMs"
$Organization = "MVP Rockstars"
$Owner = "Dave Kawula"
$Timezone = "Pacific Standard Time"
$adminPassword = "P@ssw0rd"
$domainName = "MVPDays.Com"
$domainAdminPassword = "P@ssw0rd"
$virtualSwitchName = "Dave MVP Demo"
$subnet = "172.16.200."

$localCred1 = new-object -typename System.Management.Automation.PSCredential `
             -argumentlist ".\Administrator", (ConvertTo-SecureString $adminPassword -AsPlainText -Force)

$localCred = new-object -typename System.Management.Automation.PSCredential `
             -argumentlist "Administrator", (ConvertTo-SecureString $adminPassword -AsPlainText -Force)
$domainCred = new-object -typename System.Management.Automation.PSCredential `
              -argumentlist "$($domainName)\Administrator", (ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force)
#$ServerISO = "D:\DCBuild\10586.0.151029-1700.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO"
#$ServerISO = "d:\DCBuild\14393.0.160808-1702.RS1_Release_srvmedia_SERVER_OEMRET_X64FRE_EN-US.ISO"
$ServerISO = "D:\DCBuild\en_windows_server_2016_technical_preview_5_x64_dvd_8512312.iso"

#$WindowsKey = "2KNJJ-33Y9H-2GXGX-KMQWH-G6H67"
$WindowsKey = "6XBNX-4JQGW-QX6QG-74P76-72V67"

### Sysprep unattend XML
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

function waitForPSDirect([string]$VMName, $cred){
   logger $VMName "Waiting for PowerShell Direct (using $($cred.username))"
   while ((icm -VMName $VMName -Credential $cred {"Test"} -ea SilentlyContinue) -ne "Test") {Sleep -Seconds 1}}

function rebootVM([string]$VMName){logger $VMName "Rebooting"; stop-vm $VMName; start-vm $VMName}

# Helper function to make sure that needed folders are present
function checkPath
{
    param
    (
        [string] $path
    )
    if (!(Test-Path $path)) 
    {
        $null = md $path;
    }
}

function Logger {
    param
    (
        [string]$systemName,
        [string]$message
    );

    # Function for displaying formatted log messages.  Also displays time in minutes since the script was started
    write-host (Get-Date).ToShortTimeString() -ForegroundColor Cyan -NoNewline;
    write-host " - [" -ForegroundColor White -NoNewline;
    write-host $systemName -ForegroundColor Yellow -NoNewline;
    write-Host "]::$($message)" -ForegroundColor White;
}

# Helper function for no error file cleanup
function cleanupFile
{
    param
    (
        [string] $file
    )
    
    if (Test-Path $file) 
    {
        Remove-Item $file -Recurse > $null;
    }
}

function GetUnattendChunk 
{
    param
    (
        [string] $pass, 
        [string] $component, 
        [xml] $unattend
    ); 
    
    # Helper function that returns one component chunk from the Unattend XML data structure
    return $Unattend.unattend.settings | ? pass -eq $pass `
        | select -ExpandProperty component `
        | ? name -eq $component;
}

function makeUnattendFile 
{
    param
    (
        [string] $filePath
    ); 

    # Composes unattend file and writes it to the specified filepath
     
    # Reload template - clone is necessary as PowerShell thinks this is a "complex" object
    $unattend = $unattendSource.Clone();
     
    # Customize unattend XML
    GetUnattendChunk "specialize" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.RegisteredOrganization = $Organization};
    GetUnattendChunk "specialize" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.RegisteredOwner = $Owner};
    GetUnattendChunk "specialize" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.TimeZone = $Timezone};
    GetUnattendChunk "oobeSystem" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.UserAccounts.AdministratorPassword.Value = $adminPassword};
    GetUnattendChunk "specialize" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.ProductKey = $WindowsKey};

    # Write it out to disk
    cleanupFile $filePath; $Unattend.Save($filePath);
}

# Build base VHDs

Function BuildBaseImages {

   Mount-DiskImage $ServerISO
   $DVDDriveLetter = (Get-DiskImage $ServerISO | Get-Volume).DriveLetter
   Copy-Item "$($DVDDriveLetter):\NanoServer\NanoServerImageGenerator\Convert-WindowsImage.ps1" "$($workingDir)\Convert-WindowsImage.ps1" -Force
   Import-Module "$($DVDDriveLetter):\NanoServer\NanoServerImagegenerator\NanoServerImageGenerator.psm1" -Force

   

   <#>
    if (!(Test-Path "$($BaseVHDPath)\NanoBase.vhdx")) 
    {
    New-NanoServerImage -MediaPath "$($DVDDriveLetter):\" -BasePath $BaseVHDPath -TargetPath "$($BaseVHDPath)\NanoBase.vhdx" -Edition Standard -DeploymentType Guest -Compute -Clustering -AdministratorPassword (ConvertTo-SecureString $adminPassword -AsPlainText -Force)
    }
   </#>
    Copy-Item "D:\working\Convert-WindowsImage.ps1" "$($workingDir)\Convert-WindowsImage.ps1" -Force
    makeUnattendFile "$BaseVHDPath\unattend.xml"
   
    <#>
    if (!(Test-Path "$($BaseVHDPath)\VMServerBaseCore.vhdx")) 
    {
        . "$workingDir\Convert-WindowsImage.ps1" -SourcePath "$($DVDDriveLetter):\sources\install.wim" -VHDPath "$($BaseVHDPath)\VMServerBaseCore.vhdx" `
                     -SizeBytes 40GB -VHDFormat VHDX -UnattendPath "$($BaseVHDPath)\unattend.xml" `
                     -Edition "ServerDataCenterCore" -VHDPartitionStyle GPT
                     
    }
    </#>
  
    Copy-Item "D:\working\Convert-WindowsImage.ps1" "$($workingDir)\Convert-WindowsImage.ps1" -Force
    
    if (!(Test-Path "$($BaseVHDPath)\VMServerBase.vhdx")) 
    {
        . "$workingDir\Convert-WindowsImage.ps1" -SourcePath "$($DVDDriveLetter):\sources\install.wim" -VHDPath "$($BaseVHDPath)\VMServerBase.vhdx" `
                     -SizeBytes 40GB -VHDFormat VHDX -UnattendPath "$($BaseVHDPath)\unattend.xml" `
                     -Edition "ServerDataCenter" -VHDPartitionStyle GPT
                    
                         }

    cleanupFile "$($BaseVHDPath)\unattend.xml"
    Dismount-DiskImage $ServerISO 
     cleanupFile "$($workingDir)\Convert-WindowsImage.ps1"
}

function PrepVM {

    param
    (
        [string] $VMName, 
        [string] $GuestOSName, 
        [switch] $FullServer
    ); 

   logger $VMName "Removing old VM"
   get-vm $VMName -ErrorAction SilentlyContinue | stop-vm -TurnOff -Force -Passthru | remove-vm -Force
   cleanupFile "$($VMPath)\$($GuestOSName).vhdx"
   
   # Make new VM
   logger $VMName "Creating new differencing disk"
   if ($FullServer) { New-VHD -Path "$($VMPath)\$($GuestOSName).vhdx" -ParentPath "$($BaseVHDPath)\VMServerBase.vhdx" -Differencing | Out-Null}
   else {New-VHD -Path "$($VMPath)\$($GuestOSName).vhdx" -ParentPath "$($BaseVHDPath)\VMServerBaseCore.vhdx" -Differencing | Out-Null}
   logger $VMName "Creating virtual machine"
   new-vm -Name $VMName -MemoryStartupBytes 4GB -SwitchName $VirtualSwitchName `
          -Generation 2 -Path "$($VMPath)\" | Set-VM -ProcessorCount 2 
   Set-VMFirmware -VMName $VMName -SecureBootTemplate MicrosoftUEFICertificateAuthority
   Set-VMFirmware -Vmname $VMName -EnableSecureBoot off
   Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName).vhdx" -ControllerType SCSI
   logger $VMName "Starting virtual machine"
   start-vm $VMName
   }

function CreateVM {

    param
    (
        [string] $VMName, 
        [string] $GuestOSName, 
        [string] $IPNumber = "0"
    ); 

   waitForPSDirect $VMName -cred $localCred

   # Set IP address & name
   icm -VMName $VMName -Credential $localCred {
      param($IPNumber, $GuestOSName,  $VMName, $domainName, $subnet)
      if ($IPNumber -ne "0") {
         Write-Output "[$($VMName)]:: Setting IP Address to $($subnet)$($IPNumber)"
         New-NetIPAddress -IPAddress "$($subnet)$($IPNumber)" -InterfaceAlias "Ethernet" -PrefixLength 24 | Out-Null
         Write-Output "[$($VMName)]:: Setting DNS Address"
         Get-DnsClientServerAddress | %{Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses "$($subnet)1"}}
      Write-Output "[$($VMName)]:: Renaming OS to `"$($GuestOSName)`""
      Rename-Computer $GuestOSName
      Write-Output "[$($VMName)]:: Configuring WSMAN Trusted hosts"
      Set-Item WSMan:\localhost\Client\TrustedHosts "*.$($domainName)" -Force
      Set-Item WSMan:\localhost\client\trustedhosts "$($subnet)*" -force -concatenate
      Enable-WSManCredSSP -Role Client -DelegateComputer "*.$($domainName)" -Force
      } -ArgumentList $IPNumber, $GuestOSName, $VMName, $domainName, $subnet

      # Reboot
      rebootVM $VMName; waitForPSDirect $VMName -cred $localCred

}

logger "Host" "Getting started..."

checkpath $BaseVHDPath
checkpath $VMPath
Logger "Host" "Building Base Images"

 if (!(Test-Path "$($BaseVHDPath)\VMServerBase.vhdx")) 
    {
        . BuildBaseImages
                    
                         }


#BuildBaseImages

if ((Get-VMSwitch | ? name -eq $virtualSwitchName) -eq $null)
{
New-VMSwitch -Name $virtualSwitchName -SwitchType Private
}

PrepVM "Domain Controller 1" "DC1" -FullServer
#PrepVM "Container Host" "ConHost"-FullServer
PrepVM "Domain Controller 2" "DC2"-FullServer
PrepVM "DHCP Server" "DHCP"-FullServer
PrepVM "Management Console" "Management" -FullServer
PrepVM "S2DNode1" "S2DNode1" -FullServer
PrepVM "S2DNode2" "S2DNode2" -FullServer
PrepVM "S2DNode3" "S2DNode3" -FullServer
PrepVM "S2DNode4" "S2DNode4" -FullServer
PrepVM "5nine Mgr" "5nine01" -FullServer
PrepVM "Veeam Backup" "Veeam01" -FullServer
PrepVM "Internet Router" "Router" -FullServer
PrepVM "Deployment Server" "MDT01" -FullServer


$vmName = "Domain Controller 1"
$GuestOSName = "DC1"
$IPNumber = "1"

CreateVM $vmName $GuestOSName $IPNumber

      icm -VMName $VMName -Credential $localCred {
         param($VMName, $domainName, $domainAdminPassword)
         Write-Output "[$($VMName)]:: Installing AD"
         Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | out-null
         Write-Output "[$($VMName)]:: Enabling Active Directory and promoting to domain controller"
         Install-ADDSForest -DomainName $domainName -InstallDNS -NoDNSonNetwork -NoRebootOnCompletion `
                            -SafeModeAdministratorPassword (ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force) -confirm:$false
                            } -ArgumentList $VMName, $domainName, $domainAdminPassword


      # Reboot
      rebootVM $VMName; 


      

$vmName = "Veeam Backup"
$GuestOSName = "Veeam01"
$IPNumber = "250"



CreateVM $vmName $GuestOSName $IPNumber 

    icm -VMName $VMName -Credential $localCred {
         param($VMName, $domainCred, $domainName)
         Write-Output "[$($VMName)]:: Joining domain as `"$($env:computername)`""
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
         } -ArgumentList $VMName, $domainCred, $domainName

 # Reboot
 rebootVM $VMName; 


$vmName = "5nine MGR"
$GuestOSName = "5nine01"
$IPNumber = "249"



CreateVM $vmName $GuestOSName $IPNumber

        icm -VMName $VMName -Credential $localCred {
         param($VMName, $domainCred, $domainName)
         Write-Output "[$($VMName)]:: Joining domain as `"$($env:computername)`""
        Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue
         } -ArgumentList $VMName, $domainCred, $domainName

 # Reboot
 rebootVM $VMName; 

 $vmName = "Internet Router"
$GuestOSName = "Router"
$IPNumber = "248"



CreateVM $vmName $GuestOSName $IPNumber

 # Reboot
 rebootVM $VMName; 


 $vmName = "Deployment Server"
$GuestOSName = "MDT01"
$IPNumber = "247"



CreateVM $vmName $GuestOSName $IPNumber

 
 <#>     
$vmName = "Container Host"
$GuestOSName =  "ConHost"

   waitForPSDirect $VMName -cred $localCred

   logger $VMName "Enabling Containers Feature"
   icm -VMName $VMName -Credential $localCred {install-windowsfeature containers} 

   # Reboot
   rebootVM $VMName; waitForPSDirect $VMName -cred $localCred

   logger $VMName "Starting background installation of the Container Base OS Image"
$job = icm -VMName $VMName -Credential $localCred {
        Install-ContainerOSImage C:\CBaseOs_th2_release_10586.0.151029-1700_amd64fre_ServerDatacenterCore_en-us.wim -Force} -asjob
</#>

$vmName = "DHCP Server"
$GuestOSName = "DHCP"
$IPNumber = "3"

CreateVM $vmName $GuestOSName $IPNumber

      icm -VMName $VMName -Credential $localCred {
         param($VMName, $domainCred, $domainName)
         Write-Output "[$($VMName)]:: Installing DHCP"
         Install-WindowsFeature DHCP -IncludeManagementTools | out-null
         Write-Output "[$($VMName)]:: Joining domain as `"$($env:computername)`""
         while (!(Test-Connection -Computername $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {sleep -seconds 1}
         do {Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue} until ($?)
         } -ArgumentList $VMName, $domainCred, $domainName

               # Reboot
      rebootVM $VMName; waitForPSDirect $VMName -cred $domainCred

      icm -VMName $VMName -Credential $domainCred {
         param($VMName, $domainName, $subnet, $IPNumber)

         Write-Output "[$($VMName)]:: Waiting for name resolution"

         while ((Test-NetConnection -ComputerName $domainName).PingSucceeded -eq $false) {Start-Sleep 1}

         Write-Output "[$($VMName)]:: Configuring DHCP Server"    
         Set-DhcpServerv4Binding -BindingState $true -InterfaceAlias Ethernet
         Add-DhcpServerv4Scope -Name "IPv4 Network" -StartRange "$($subnet)10" -EndRange "$($subnet)200" -SubnetMask 255.255.255.0
         Set-DhcpServerv4OptionValue -OptionId 6 -value "$($subnet)1"
         Add-DhcpServerInDC -DnsName "$($env:computername).$($domainName)"
         foreach($i in 1..99) {
         $mac = "00-b5-5d-fe-f6-" + ($i % 100).ToString("00")
         $ip = $subnet + "1" + ($i % 100).ToString("00")
         $desc = "Container " + $i.ToString()
         $scopeID = $subnet + "0"
         Add-DhcpServerv4Reservation -IPAddress $ip -ClientId $mac -Description $desc -ScopeId $scopeID}
                            } -ArgumentList $VMName, $domainName, $subnet, $IPNumber

      # Reboot
      rebootVM $VMName

$vmName = "Domain Controller 2"
$GuestOSName = "DC2"
$IPNumber = "2"

CreateVM $vmName $GuestOSName $IPNumber

      icm -VMName $VMName -Credential $localCred {
         param($VMName, $domainCred, $domainName)
         Write-Output "[$($VMName)]:: Installing AD"
         Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | out-null
         Write-Output "[$($VMName)]:: Joining domain as `"$($env:computername)`""
         while (!(Test-Connection -Computername $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {sleep -seconds 1}
         do {Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue} until ($?)
         } -ArgumentList $VMName, $domainCred, $domainName

               # Reboot
      rebootVM $VMName; waitForPSDirect $VMName -cred $domainCred

      icm -VMName $VMName -Credential $domainCred {
         param($VMName, $domainName, $domainAdminPassword)

         Write-Output "[$($VMName)]:: Waiting for name resolution"

         while ((Test-NetConnection -ComputerName $domainName).PingSucceeded -eq $false) {Start-Sleep 1}

         Write-Output "[$($VMName)]:: Enabling Active Directory and promoting to domain controller"
    
         Install-ADDSDomainController -DomainName $domainName -InstallDNS -NoRebootOnCompletion `
                                     -SafeModeAdministratorPassword (ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force) -confirm:$false 
 
                            } -ArgumentList $VMName, $domainName, $domainAdminPassword

      # Reboot
      rebootVM $VMName

$vmName = "Domain Controller 1"
$GuestOSName = "DC1"
$IPNumber = "1"

waitForPSDirect $VMName -cred $domainCred

icm -VMName $VMName -Credential $domainCred {
         param($VMName, $password)

         Write-Output "[$($VMName)]:: Creating user account for Dave"
         do {start-sleep 5; New-ADUser `
            -Name "Dave" `
            -SamAccountName  "Dave" `
            -DisplayName "Dave" `
            -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) `
            -ChangePasswordAtLogon $false  `
            -Enabled $true -ea 0} until ($?)
            Add-ADGroupMember "Domain Admins" "Dave"} -ArgumentList $VMName, $domainAdminPassword

$vmName = "Management Console"
$GuestOSName = "Management"

CreateVM $vmName $GuestOSName

      icm -VMName $VMName -Credential $localCred {
         param($VMName, $domainCred, $domainName)
         Write-Output "[$($VMName)]:: Management tools"
         Install-WindowsFeature RSAT-Clustering, RSAT-Hyper-V-Tools | out-null
         Write-Output "[$($VMName)]:: Joining domain as `"$($env:computername)`""
         while (!(Test-Connection -Computername $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {sleep -seconds 1}
         do {Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue} until ($?)
         } -ArgumentList $VMName, $domainCred, $domainName

      # Reboot
      rebootVM $VMName

$vmName = 'S2DNode1'
$GuestOSName = 'S2Dnode1'
function BuildStorageNode {
param($VMName, $GuestOSName)

CreateVM $vmName $GuestOSName

   cleanupFile "$($VMPath)\$($GuestOSName) - Data 1.vhdx"
   cleanupFile "$($VMPath)\$($GuestOSName) - Data 2.vhdx"
   Get-VM $VMName | Stop-VM 
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   new-vhd -Path "$($VMPath)\$($GuestOSName) - Data 1.vhdx" -Dynamic -SizeBytes 200GB 
   Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - Data 1.vhdx" -ControllerType SCSI
   new-vhd -Path "$($VMPath)\$($GuestOSName) - Data 2.vhdx" -Dynamic -SizeBytes 200GB
   Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName) - Data 2.vhdx" -ControllerType SCSI
   Set-VMProcessor -VMName $VMName -Count 2 -ExposeVirtualizationExtensions $true
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -AllowTeaming On
   Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing on
   Start-VM $vmname
   waitForPSDirect $VMName -cred $localCred

      icm -VMName $VMName -Credential $localCred {
         param($VMName, $domainCred, $domainName)
         Write-Output "[$($VMName)]:: Installing Clustering"
         Install-WindowsFeature -Name File-Services, Failover-Clustering,Hyper-V -IncludeManagementTools | out-null
         Write-Output "[$($VMName)]:: Joining domain as `"$($env:computername)`""
         while (!(Test-Connection -Computername $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {sleep -seconds 1}
         do {Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue} until ($?)
         } -ArgumentList $VMName, $domainCred, $domainName

#Configure the rest of the Virtual Adapters
  icm -VMName $vmname -Credential $localcred1 {Rename-NetAdapter -Name "Ethernet" -NewName "LOM-P0"}
  icm -VMName $vmname -Credential $localcred1 {Rename-NetAdapter -Name "Ethernet 2" -NewName "LOM-P1"}
  icm -VMName $vmname -Credential $localcred1 {Rename-NetAdapter -Name "Ethernet 3" -NewName "Riser-P0"}
  icm -VMName $vmname -Credential $localcred1 {Get-NetAdapter -Name "Ethernet 5" | Rename-NetAdapter -NewName "Riser-P1"}
  icm -VMName $vmname -Credential $localcred1 {New-NetLbfoTeam -Name HyperVTeam -TeamMembers "LOM-P0" -verbose -confirm:$false}
  icm -VMName $vmname -Credential $localcred1 {Add-NetLbfoTeammember "LOM-P1" -team HyperVTeam -confirm:$false}
  icm -VMName $vmname -Credential $localcred1 {New-NetLbfoTeam -Name StorageTeam -TeamMembers "Riser-P0" -verbose -confirm:$false}
  icm -VMName $vmname -Credential $localcred1 {Add-NetLbfoTeammember "Riser-P1" -team StorageTeam -confirm:$false}
   RebootVM $VMName
   waitForPSDirect $VMName -cred $domainCred
  icm -VMName $vmname -Credential $domainCred {New-VMSwitch -Name "VSW01" -NetAdapterName "HyperVTeam" -AllowManagementOS $False}
  icm -VMName $vmname -Credential $domainCred {Add-VMNetworkAdapter -ManagementOS -Name ClusterCSV-VLAN204 -Switchname VSW01 -verbose}
  icm -VMName $vmname -Credential $domainCred {Add-VMNetworkAdapter -ManagementOS -Name LM-VLAN203 -Switchname VSW01 -verbose}
  icm -VMName $vmname -Credential $domainCred {Add-VMNetworkAdapter -ManagementOS -Name Servers-VLAN201 -Switchname VSW01 -verbose}
  icm -VMName $vmname -Credential $domainCred {Add-VMNetworkAdapter -ManagementOS -Name MGMT-VLAN200 -Switchname VSW01 -verbose}
      # Reboot
      rebootVM $VMName
}

BuildStorageNode "S2DNode1" "S2DNode1" 
BuildStorageNode "S2DNode2" "S2DNode2"
BuildStorageNode "S2DNode3" "S2DNode3"
BuildStorageNode "S2DNode4" "S2DNode4"

waitForPSDirect "S2DNode4" -cred $domainCred

icm -VMName "Management Console" -Credential $domainCred {
param ($domainName)
do {New-Cluster -Name S2DCluster -Node S2DNode1,S2DNode2,S2DNode3,S2DNode4 -NoStorage} until ($?)
while (!(Test-Connection -Computername "S2DCluster.$($domainName)" -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
      {ipconfig /flushdns; sleep -seconds 1}
#Enable-ClusterStorageSpacesDirect -Cluster "S2DCluster.$($domainName)"
Add-ClusterScaleoutFileServerRole -name S2DFileServer -cluster "S2DCluster.$($domainName)"
} -ArgumentList $domainName

icm -VMName "S2DNode1" -Credential $domainCred {
param ($domainName)
#New-StoragePool -StorageSubSystemName "S2DCluster.$($domainName)" -FriendlyName S2DPool -WriteCacheSizeDefault 0 -ProvisioningTypeDefault Fixed -ResiliencySettingNameDefault Mirror -PhysicalDisk (Get-StorageSubSystem  -Name "S2DCluster.$($domainName)" | Get-PhysicalDisk)
#New-Volume -StoragePoolFriendlyName S2DPool -FriendlyName S2DDisk -PhysicalDiskRedundancy 2 -FileSystem CSVFS_REFS -Size 500GB
#updated from MSFT TP5 notes

#Create cluster and enable S2D
#New-Cluster -Name CJ-CLU -Node node1,node2,node3 -NoStorage
Enable-ClusterS2D -CacheMode Disabled -AutoConfig:0 -SkipEligibilityChecks -confirm:$false

#Create storage pool and set media type to HDD
New-StoragePool -StorageSubSystemFriendlyName *Cluster* -FriendlyName S2D -ProvisioningTypeDefault Fixed -PhysicalDisk (Get-PhysicalDisk | ? CanPool -eq $true)

Get-StorageSubsystem *cluster* | Get-PhysicalDisk | Where MediaType -eq "UnSpecified" | Set-PhysicalDisk -MediaType HDD

#Create storage tiers
$pool = Get-StoragePool S2D
New-StorageTier -StoragePoolUniqueID ($pool).UniqueID -FriendlyName Performance -MediaType HDD -ResiliencySettingName Mirror
New-StorageTier -StoragePoolUniqueID ($pool).UniqueID -FriendlyName Capacity -MediaType HDD -ResiliencySettingName Parity

#Create a volume
New-Volume -StoragePoolFriendlyName S2D -FriendlyName Mirror -FileSystem CSVFS_REFS -Size 200GB -PhysicalDiskRedundancy 2
New-Volume -StoragePoolFriendlyName S2D -FriendlyName Parity1 -FileSystem CSVFS_REFS -Size 200GB -PhysicalDiskRedundancy 1
Set-FileIntegrity "C:\ClusterStorage\Volume1" -Enable $false

         MD C:\ClusterStorage\Volume1\VHDX
         New-SmbShare -Name VHDX -Path C:\ClusterStorage\Volume1\VHDX -FullAccess "$($domainName)\administrator", "$($domainName)\Dave", "$($domainName)\Management$"
         Set-SmbPathAcl -ShareName VHDX

         MD C:\ClusterStorage\Volume1\ClusQuorum
         New-SmbShare -Name ClusQuorum -Path C:\ClusterStorage\Volume1\ClusQuorum -FullAccess "$($domainName)\administrator", "$($domainName)\Dave", "$($domainName)\Management$"
         Set-SmbPathAcl -ShareName ClusQuorum

         MD C:\ClusterStorage\Volume1\ClusData
         New-SmbShare -Name ClusData -Path C:\ClusterStorage\Volume1\ClusData -FullAccess "$($domainName)\administrator", "$($domainName)\Dave", "$($domainName)\Management$"
         Set-SmbPathAcl -ShareName ClusData

} -ArgumentList $domainName


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

function PrepComputeNode {
param($VMName, $GuestOSName)

   logger $VMName "Removing old VM"
   get-vm $VMName -ErrorAction SilentlyContinue | stop-vm -TurnOff -Force -Passthru | remove-vm -Force
   cleanupFile "$($VMPath)\$($GuestOSName).vhdx"

   copy "$($BaseVHDPath)\VMServerBase.vhdx" "$($VMPath)\$($GuestOSName).vhdx"

   # Make new VM
   logger $VMName "Creating virtual machine"
   new-vm -Name $VMName -MemoryStartupBytes 12384MB -SwitchName $VirtualSwitchName `
          -Generation 2 -Path "$($VMPath)\$($GuestOSName)"
   Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false
   Set-VMProcessor -VMName $VMName -Count 2 -ExposeVirtualizationExtensions $true
   Set-VMFirmware -VMName $VMName -SecureBootTemplate MicrosoftUEFICertificateAuthority
   Set-VMFirmware -VMName $VMName -EnableSecureBoot off
   Add-VMHardDiskDrive -VMName $VMName -Path "$($VMPath)\$($GuestOSName).vhdx" -ControllerType SCSI
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -AllowTeaming On
   Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing on
   logger $VMName "Starting virtual machine"
   do {start-vm $VMName} until ($?)
}

function BuildComputeNode {
param($VMName, $GuestOSName)

CreateVM $vmName $GuestOSName

   Get-VM $VMName | Stop-VM 
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   Set-VMProcessor -VMName $VMName -Count 2 -ExposeVirtualizationExtensions $true
   Set-VMMemory -VMName $VMName -StartupBytes 16GB
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   Add-VMNetworkAdapter -VMName $VMName -SwitchName $VirtualSwitchName
   Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -AllowTeaming On
   Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing on
   Start-VM $vmname
   waitForPSDirect $VMName -cred $localCred

      icm -VMName $VMName -Credential $localCred {
         param($VMName, $domainCred, $domainName)
         Write-Output "[$($VMName)]:: Installing Clustering"
         Install-WindowsFeature -Name File-Services, Failover-Clustering,Hyper-V -IncludeManagementTools | out-null
         Restart-VM
         Write-Output "[$($VMName)]:: Joining domain as `"$($env:computername)`""
         while (!(Test-Connection -Computername $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {sleep -seconds 1}
         do {Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue} until ($?)
         } -ArgumentList $VMName, $domainCred, $domainName

 #Configure the rest of the Virtual Adapters
  icm -VMName $vmname -Credential $localcred1 {Rename-NetAdapter -Name "Ethernet" -NewName "LOM-P0"}
  icm -VMName $vmname -Credential $localcred1 {Rename-NetAdapter -Name "Ethernet 2" -NewName "LOM-P1"}
  icm -VMName $vmname -Credential $localcred1 {Rename-NetAdapter -Name "Ethernet 3" -NewName "Riser-P0"}
  icm -VMName $vmname -Credential $localcred1 {Get-NetAdapter -Name "Ethernet 5" | Rename-NetAdapter -NewName "Riser-P1"}
  icm -VMName $vmname -Credential $localcred1 {New-NetLbfoTeam -Name HyperVTeam -TeamMembers "LOM-P0" -verbose -confirm:$false}
  icm -VMName $vmname -Credential $localcred1 {Add-NetLbfoTeammember "LOM-P1" -team HyperVTeam -confirm:$false}
  icm -VMName $vmname -Credential $localcred1 {New-NetLbfoTeam -Name StorageTeam -TeamMembers "Riser-P0" -verbose -confirm:$false}
  icm -VMName $vmname -Credential $localcred1 {Add-NetLbfoTeammember "Riser-P1" -team StorageTeam -confirm:$false}
  icm -VMName $vmname -Credential $localcred1 {Ping localhost -n 10}
  rebootVM $vmanme
  waitForPSDirect $VMName -cred $domainCred
  icm -VMName $vmname -Credential $domainCred {New-VMSwitch -Name "VSW01" -NetAdapterName "HyperVTeam" -AllowManagementOS $False}
  icm -VMName $vmname -Credential $domainCred {Add-VMNetworkAdapter -ManagementOS -Name ClusterCSV-VLAN204 -Switchname VSW01 -verbose}
  icm -VMName $vmname -Credential $domainCred {Add-VMNetworkAdapter -ManagementOS -Name LM-VLAN203 -Switchname VSW01 -verbose}
  icm -VMName $vmname -Credential $domainCred {Add-VMNetworkAdapter -ManagementOS -Name Servers-VLAN201 -Switchname VSW01 -verbose}
  icm -VMName $vmname -Credential $domainCred {Add-VMNetworkAdapter -ManagementOS -Name MGMT-VLAN200 -Switchname VSW01 -verbose}
      # Reboot
      rebootVM $VMName
}



<#>
function BuildComputeNode {

 param
    (
        [string] $VMName, 
        [string] $GuestOSName, 
        [string] $IPNumber = "0"
    ); 

    waitForPSDirect $VMName $localcred1

    ping localhost -n 30

   # icm -VMName $VMName -Credential $localcred1 { Add-WindowsFeature Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart}
    icm -VMName $VMName -Credential $localcred1 { New-Item -ItemType Directory c:\sym}
    icm -VMName $VMName -Credential $localcred1 { schtasks.exe /change /disable /tn "\Microsoft\Windows\Defrag\ScheduledDefrag" }
    #icm -VMName $VMName -Credential $localcred1 { sc config w32time start=delayed-auto }
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"netfx3" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"netfx4" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"qwave" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"snmp" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"wmisnmpprovider" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"server-rsat-snmp" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"telnetclient" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"WindowsStorageManagementService" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"microsoft-hyper-v" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"microsoft-hyper-v-offline" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"microsoft-hyper-v-online" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"rsat-hyper-v-tools-feature" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"microsoft-hyper-v-management-clients" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"microsoft-hyper-v-management-powershell" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"failovercluster-mgmt" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"failovercluster-adminpak" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"failovercluster-powershell" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"failovercluster-automationserver" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"failovercluster-cmdinterface" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { dism /online /enable-feature /featurename:"failovercluster-fullserver" /all /norestart}
           icm -VMName $VMName -Credential $localcred1 { reg add "HKLM\SOFTWARE\GSFW" /v fw_version /t REG_SZ /d "22X" /f}
           icm -VMName $VMName -Credential $localcred1 { reg add "HKLM\SOFTWARE\GSFW" /v baseboard /t REG_SZ /d "X10DRT-PT" /f }
           icm -VMName $VMName -Credential $localcred1 { reg add "HKLM\Software\GSFW" /v node_model /t REG_SZ /d "GS-3000-FCN" /f}
           icm -VMName $VMName -Credential $localcred1 { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v GSFW_VERSION /t REG_SZ /d %VER_STRING% /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v _NT_DEBUG_CACHE_SIZE /t REG_SZ /d "4096000" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v _NT_SYMBOL_PATH /t REG_SZ /d "SRV*c:\\sym*http://msdl.microsoft.com/download/symbols;C:\\windows\\system32;C:\\Program Files\\Gridstore;C:\\Program Files (x86)\\Gridstore;C:\\Program Files\\Gridstore\\NDFS;C:\\Program Files (x86)\\Gridstore\\NDFS;" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v _NT_SYMCACHE_PATH /t REG_SZ /d "c:\\sym" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "PagingFiles" /t REG_MULTI_SZ /d "c:\pagefile.sys 10480 10480" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v "CrashDumpEnabled" /t REG_DWORD /d "2" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v "AutoReboot" /t REG_DWORD /d "1" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v "NMICrashDump" /t REG_DWORD /d "1" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Services\i8042prt\Parameters" /v "CrashOnCtrlScroll" /t REG_DWORD /d "1" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdhid\Parameters" /v "CrashOnCtrlScroll" /t REG_DWORD /d "1" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v verbosestatus /t REG_DWORD /d 1 /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v "fDenyTSConnections" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "UserAuthentication" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "MaxIdleTime" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "MaxConnectionTime" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "MaxDisconnectionTime" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "fResetBroken" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "RemoteAppLogoffTimeLimit" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxIdleTime" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxConnectionTime" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxDisconnectionTime" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fResetBroken" /t REG_DWORD /d "0" /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "RemoteAppLogoffTimeLimit" /t REG_DWORD /d "0" /f}
          # icm -VMName $VMName -Credential $localcred1 {reg add "HKU\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxIdleTime" /t REG_DWORD /d "0" /f}
          # icm -VMName $VMName -Credential $localcred1 {reg add "HKU\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxConnectionTime" /t REG_DWORD /d "0" /f}
          # icm -VMName $VMName -Credential $localcred1 {reg add "HKU\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "MaxDisconnectionTime" /t REG_DWORD /d "0" /f}
          # icm -VMName $VMName -Credential $localcred1 {reg add "HKU\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fResetBroken" /t REG_DWORD /d "0" /f}
          # icm -VMName $VMName -Credential $localcred1 {reg add "HKU\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "RemoteAppLogoffTimeLimit" /t REG_DWORD /d "0" /f}

           #::reg add "HKLM\SOFTWARE\Microsoft\WindowsNT\CurrentVersion\SoftwareProtectionPlatform" /v SkipRearm /t REG_DWORD /d 1 /f
           icm -VMName $VMName -Credential $localcred1 {reg add "HKLM\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration"}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKCU\Software\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 0x1 /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKCU\Console" /v QuickEdit /t REG_DWORD /d 1 /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" /v AllItemsIconView /t REG_DWORD /d 1 /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" /v StartupPage /t REG_DWORD /d 1 /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 0 /f}
           icm -VMName $VMName -Credential $localcred1 {reg add "HKCU\Software\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 0x1 /f}
            #::reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\010103000F0000F0010000000F0000F0C967A3643C3AD745950DA7859209176EF5B87C875FA20DF21951640E807D7C24" /v Category /t REG_DWORD /d 0x00000001 /f
            #::reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Group Policy Objects\{84CD9509-EFA7-40A9-A990-CF68B6E4C3C0}Machine\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\010103000F0000F0010000000F0000F0C967A3643C3AD745950DA7859209176EF5B87C875FA20DF21951640E807D7C24" /v Category /t REG_DWORD /d 0x1 /f
            #::reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Group Policy Objects\{864C7F14-370F-4504-A10F-4D03605D73DE}Machine\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\010103000F0000F0010000000F0000F0C967A3643C3AD745950DA7859209176EF5B87C875FA20DF21951640E807D7C24" /v Category /t REG_DWORD /d 0x1 /f

           icm -VMName $VMName -Credential $localcred1 { netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes}
           icm -VMName $VMName -Credential $localcred1 {netsh advfirewall firewall set rule name="File and Printer Sharing (Echo Request - ICMPv4-In)" new enable=yes}

           icm -VMName $VMName -Credential $localcred1 {powercfg -s SCHEME_MIN}
           #::wmic useraccount where "name='admin'" set passwordexpires=false

           #::cscript c:\windows\system32\slmgr.vbs /upk

           #reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 0 /f

                

   waitForPSDirect $VMName $localCred1
      Write-Output "[$($VMName)]:: Renaming OS to `"$($GuestOSName)`""
     icm -VMName $VManme -Credential $localcred1{
     Rename-Computer $GuestOSName} -ArgumentList $VMName
      # Reboot
      rebootVM $VMName; 
   waitForPSDirect $VMName $localCred1
     #  rebootVM $VMName; 
   waitForPSDirect $VMName $localCred1
    icm -VMName $VMName -Credential $localCred1 {
         param($VMName, $domainCred, $domainName)
            
         Write-Output "[$($VMName)]:: Joining domain as `"$($env:computername)`""
         while (!(Test-Connection -Computername $domainName -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) {sleep -seconds 1}
         do {Add-Computer -DomainName $domainName -Credential $domainCred -ea SilentlyContinue} until ($?)
         } -ArgumentList $VMName, $domainCred, $domainName

               # Reboot
      rebootVM $VMName; waitForPSDirect $VMName -cred $domainCred
  
  
  
  
  
  
  #     icm -VMName $VMName -Credential $localcred1 {Add-Computer -ComputerName $GuestOSName -DomainName mvpdays.com -Credential $domainCred -LocalCredential $localcred1 -Restart}

 waitForPSDirect $VMName $localCred1

 icm -VMName $VMName -Credential $localcred1 {enable-wsmancredssp -role server -force}
      
 waitForPSDirect $VMName $localCred1
 #Stage Files for Gridstore Virtual Grid Install
 #There are 2 x Adapters at this time - Ethernet is used for the Hyper-V Virtual Switch and Ethernet2 is free
 
 Copy-VMFile -VM $VMName.ToString() -SourcePath D:\dcbuild\Post-Install\HVHost\001-VirtualGrid\Gridstore.msi -DestinationPath c:\post-install\001-VirtualGrid\gridstore.msi -CreateFullPath -Force -verbose
  Copy-VMFile -VM $VMName.ToString() -SourcePath D:\dcbuild\Post-Install\HVHost\001-VirtualGrid\install-hca.bat -DestinationPath c:\post-install\001-VirtualGrid\install-hca.bat -CreateFullPath -Force -verbose


#Configure the rest of the Virtual Adapters
  icm -VMName $vmname -Credential $localcred1 {Rename-NetAdapter -Name "Ethernet" -NewName "LOM-P0"}
  icm -VMName $vmname -Credential $localcred1 {Rename-NetAdapter -Name "Ethernet 2" -NewName "LOM-P1"}
  icm -VMName $vmname -Credential $localcred1 {Rename-NetAdapter -Name "Ethernet 3" -NewName "Riser-P0"}
  icm -VMName $vmname -Credential $localcred1 {Rename-NetAdapter -Name "Ethernet 4" -NewName "Riser-P1"}


  icm -VMName $vmname -Credential $localcred1 {New-NetLbfoTeam -Name HyperVTeam -TeamMembers "LOM-P0" -verbose}
  icm -VMName $vmname -Credential $localcred1 {Add-NetLbfoTeammember "LOM-P1" -team HyperVTeam}
  icm -VMName $vmname -Credential $localcred1 {New-NetLbfoTeam -Name GridTeam -TeamMembers "Riser-P0" -verbose}
  icm -VMName $vmname -Credential $localcred1 {Add-NetLbfoTeammember "Riser-P1" -team Storage}
  icm -VMName $vmname -Credential $localcred1 {New-VMSwitch -Name "VSW01" -NetAdapterName "HyperVTeam" -AllowManagementOS $False}
  icm -VMName $vmname -Credential $localcred1 {Add-VMNetworkAdapter -ManagementOS -Name ClusterCSV-VLAN204 -Switchname VSW01 -verbose}
  icm -VMName $vmname -Credential $localcred1 {Add-VMNetworkAdapter -ManagementOS -Name LM-VLAN203 -Switchname VSW01 -verbose}
  icm -VMName $vmname -Credential $localcred1 {Add-VMNetworkAdapter -ManagementOS -Name Servers-VLAN201 -Switchname VSW01 -verbose}
  icm -VMName $vmname -Credential $localcred1 {Add-VMNetworkAdapter -ManagementOS -Name MGMT-VLAN200 -Switchname VSW01 -verbose}

  #icm -VMName "Hyper-V Node 8" -Credential $localcred1 {Set-VMNetworkAdapter -ManagementOS -Name "ClusterCSV-VLAN204" -MinimumBandwidthWeight 10}
  #icm -VMName "Hyper-V Node 8" -Credential $localcred1 {Set-VMNetworkAdapter -ManagementOS -Name "LM-VLAN203" -MinimumBandwidthWeight 60}
  #icm -VMName "Hyper-V Node 8" -Credential $localcred1 {Set-VMNetworkAdapter -ManagementOS -Name "Servers-VLAN201" -MinimumBandwidthWeight 15}
  #icm -VMName "Hyper-V Node 8" -Credential $localcred1 {Set-VMNetworkAdapter -ManagementOS -Name "MGMT-VLAN200" -MinimumBandwidthWeight 15}
  #icm -VMName "Hyper-V Node 8" -Credential $localcred1 {Set-VMNetworkAdaptervlan -ManagementOS -vmnetworkadapterName "VSW01" -Access -VlanId 200}
  #icm -VMName "Hyper-V Node 8" -Credential $localcred1 {Set-VMNetworkAdaptervlan -ManagementOS -Name "LM-VLAN201" -Access -VlanId 201}
  #icm -VMName "Hyper-V Node 8" -Credential $localcred1 {Set-VMNetworkAdaptervlan -ManagementOS -Name "MGMT-VLAN200" -Access -VlanId 200}

  waitForPSDirect $VMName -cred $localCred1

   # Set IP address & name
   icm -VMName $VMName -Credential $localCred1 {
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
         Get-DnsClientServerAddress | %{Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses "$($subnet)1"}}
         Write-Output "[$($VMName)]:: Configuring WSMAN Trusted hosts"
         Set-Item WSMan:\localhost\Client\TrustedHosts "*.$($domainName)" -Force
         Set-Item WSMan:\localhost\client\trustedhosts "$($subnet)*" -force -concatenate
         Enable-WSManCredSSP -Role Client -DelegateComputer "*.$($domainName)" -Force
         } -ArgumentList $IPNumber, $GuestOSName, $VMName, $domainName, $subnet

  #Don't forget to configure the DNS Suffix disable on most adapters

  #playing around with the Gridstore Installations

  icm -VMName $vmname -Credential $localcred1 {Get-NetAdapter vether* | disable-NetAdapter -Confirm:$False -ErrorAction SilentlyContinue}
  icm -VMName $vmname -Credential $localcred1 {"c:\post-install\001-virtualgrid\install-hca.bat"}

  ping localhost -n 20

  icm -VMName "$vmname" -Credential $localcred1 {Get-NetAdapter vether* | Enable-NetAdapter -confirm:$false -ErrorAction SilentlyContinue }
  }
</#>
 
   #logger $VMName "Creating standard virtual switch"

PrepComputeNode "Hyper-V Node 1" "HVNode1" 
PrepComputeNode "Hyper-V Node 2" "HVNode2"
PrepComputeNode "Hyper-V Node 3" "HVNode3"
PrepComputeNode "Hyper-V Node 4" "HVNode4"
PrepComputeNode "Hyper-V Node 5" "HVNode5"
PrepComputeNode "Hyper-V Node 6" "HVNode6"
PrepComputeNode "Hyper-V Node 7" "HVNode7"
PrepComputeNode "Hyper-V Node 8" "HVNode8"

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

BuildComputeNode "Hyper-V Node 1" "HVNode1" 
BuildComputeNode "Hyper-V Node 2" "HVNode2" 
BuildComputeNode "Hyper-V Node 3" "HVNode3" 
BuildComputeNode "Hyper-V Node 4" "HVNode4" 
BuildComputeNode "Hyper-V Node 5" "HVNode5" 
BuildComputeNode "Hyper-V Node 6" "HVNode6" 
BuildComputeNode "Hyper-V Node 7" "HVNode7" 
BuildComputeNode "Hyper-V Node 8" "HVNode8" 

waitForPSDirect "Hyper-V Node 8" -cred $domainCred


icm -VMName "Management Console" -Credential $domainCred {
param ($domainName)
do {New-Cluster -Name HVCluster -Node HVNode1,HVNode2,HVNode3,HVNode4,HVNode5,HVNode6,HVNode7,HVNode8 -NoStorage} until ($?)
while (!(Test-Connection -Computername "HVCluster.$($domainName)" -BufferSize 16 -Count 1 -Quiet -ea SilentlyContinue)) 
      {ipconfig /flushdns; sleep -seconds 1}
} -ArgumentList $domainName




<#>
cleanupFile "$($VMPath)\ConHost - Diff.vhdx"
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



logger "Done" "Done!"

