
#start-transcript -path c:\post-install\001-NetworkConfig.log
#Create the NIC Team
#New-NetlbfoTeam LOMTEAM “Ethernet”, “Ethernet 2”, "Ethernet 3", "Ethernet 4", "Ethernet 5", "Ethernet 6", –verbose
#New-NetlbfoTeam HYPERVTEAM “Ethernet 3”, “Ethernet 4” -TeamingMode Lacp –verbose -LoadBalancingAlgorithm Dynamic
#New-NetlbfoTeam GRIDTEAM “Ethernet 5”, “Ethernet 6” -TeamingMode Lacp –verbose -LoadBalancingAlgorithm Dynamic
#Get the Status of the Network Adapters
Get-NetAdapter | Sort Name
#Create the new Hyper-V Vswitch VSW01
new-vmswitch "VSW01" -MinimumBandwidthMode Weight -NetAdapterName "PRODTEAM" -verbose -AllowManagementOS $false
#Check the Bindings
Get-NetadapterBinding | where {$_.DisplayName –like “Hyper-V*”}
#Check the Adapter Settings
Get-NetAdapter | sort name
#Now Create the Converged Adapters
Add-VMNetworkAdapter –ManagementOS –Name “LM-VLAN5” –SwitchName “VSW01” –verbose
#Add-VMNetworkAdapter –ManagementOS –Name “ISCSI” –SwitchName “VSW01” –verbose
Add-VMNetworkAdapter –ManagementOS –Name “HB-VLAN6” –SwitchName “VSW01” –verbose
Add-VMNetworkAdapter –ManagementOS –Name “MGMT-VLAN1” –SwitchName “VSW01” –verbose

#Review the NIC Configuration Again
Get-NetAdapter | Sort name
#Rename the HOST NIC
#Rename-NetAdapter –Name “VEthernet (VSW01)” –NewName “vEthernet (MGMT)” –verbose
#Review the NIC Configuration Again
Get-NetAdapter | Sort name
#Set the weighting on the NIC's
Set-VMNetworkAdapter –ManagementOS –Name “LM-VLAN5” –MinimumBandwidthWeight 40
Set-VMNetworkAdapter –ManagementOS –Name “HB-VLAN6” –MinimumBandwidthWeight 10
#Set-VMNetworkAdapter –ManagementOS –Name “ISCSI” –MinimumBandwidthWeight 10
Set-VMNetworkAdapter –ManagementOS –Name “MGMT-VLAN1” –MinimumBandwidthWeight 50
#Set-VMNetworkAdapter –ManagementOS –Name “Servers” –MinimumBandwidthWeight 15

#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "ISCSI" -Access -VLanID 10
#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "LM" -Access -VLanID 1000
#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "CLUSTERCSV" -Access -VLanID 1000
#SET VLAN for Production
#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "ISCSI" -Access -VLanID 2500
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "LM-VLAN5" -Access -VLanID 5
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "HB-VLAN6" -Access -VLanID 6
#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "MGMT" -Access -VLanID 200
#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "Servers" -Access -VLanID 201

#Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "VSW01" -Access -VLanID 1000 -SecondaryVlanIDList 7

#Stop-transcript




