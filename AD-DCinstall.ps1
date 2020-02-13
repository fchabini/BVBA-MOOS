Configuration NewDomain 

{


    param(

    

        [parameter(Mandatory = $true)]
        [pscredential]$domainCred,

        [parameter(Mandatory = $true)]
        [pscredential]$safemodeAdministratorCred    

    


    )

    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -Module xComputerManagement
    Import-DscResource -ModuleName xdhcpserver


    Node $AllNodes.Where{ $_.Role -eq "Primary DC" }.NodeName
    {
        LocalConfigurationManager {
            ActionAfterReboot  = 'ContinueConfiguration'
            ConfigurationMode  = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        xIPAddress NewIPAddress
        {
            IPAddress      = "192.168.0.220/24"
            InterfaceAlias = 'Ethernet'
            AddressFamily  = "IPV4"
        }

        xDefaultGatewayAddress DefaultGateway
        {
            Address        = "192.168.0.1"
            InterfaceAlias = 'Ethernet'
            AddressFamily  = "IPV4"
        }

     
        WindowsFeature DHCP {
            DependsOn            = '[xIPAddress]NewIpAddress'
            Name                 = 'DHCP'
            Ensure               = 'PRESENT'
            IncludeAllSubFeature = $true                                                                                                                              
     
        }

        function Get-TargetResource {
            [CmdletBinding()]
            [OutputType([System.Collections.Hashtable])]
            param
            (
                [parameter(Mandatory)]
                [String]$Name,

                [parameter(Mandatory)]
                [String]$IPStartRange,

                [parameter(Mandatory)]
                [String]$IPEndRange,

                [parameter(Mandatory)]
                [String]$SubnetMask,

                [ValidateSet('IPv4')]
                [String]$AddressFamily = 'IPv4'

            )

            $dhcpScope = Get-DhcpServerv4Scope | Where-Object { ($_.StartRange -eq $IPStartRange) -and ($_.EndRange -eq $IPEndRange) }
            if ($dhcpScope) {
                $ensure = 'Present'
            }
            else {
                $ensure = 'Absent'
            }

            @{
                ScopeID       = "scope1"
                Name          = "scopeAD-DC"
                IPStartRange  = "192.168.0.223"
                IPEndRange    = "192.168.0.227"
                SubnetMask    = "255.255.255.240"
                LeaseDuration = "7:00:00"
                State         = "Active"
                AddressFamily = 'IPv4'
                Ensure        = "Present"
            }
        }

        
 
        WindowsFeature DNS { 
            Ensure = "Present" 
            Name   = "DNS"
        }

        xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            DependsOn      = "[WindowsFeature]DNS"
        }


        WindowsFeature AD-Domain-Services {

            Ensure    = "Present"
            Name      = "AD-Domain-Services"
            DependsOn = "[File]ADFiles"
        }

        WindowsFeature RSAT-DNS-Server {
            Ensure    = "Present"
            Name      = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
        }

        File ADFiles {
            DestinationPath = 'C:\NTDS'
            Type            = 'Directory'
            Ensure          = 'Present'
        }
        WindowsFeature RSAT-AD-Tools {
            Name      = 'RSAT-AD-Tools'
            Ensure    = 'Present'
            DependsOn = "[WindowsFeature]AD-Domain-Services"
        }

        WindowsFeature RSAT-ADDS {
            Ensure    = "Present"
            Name      = "RSAT-ADDS"
            DependsOn = "[WindowsFeature]AD-Domain-Services"
        }


        WindowsFeature RSAT-ADDS-Tools {   
            Name      = 'RSAT-ADDS-Tools'
            Ensure    = 'Present'
            DependsOn = "[WindowsFeature]RSAT-ADDS"
        }
     
        WindowsFeature ADDSInstall {
            Ensure = "Present"
            Name   = "AD-Domain-Services"
        }

        WindowsFeature ADDSTools {
            Ensure = 'Present'
            Name   = 'RSAT-ADDS'
        }

        WindowsFeature RSAT-AD-AdminCenter {
            Name      = 'RSAT-AD-AdminCenter'
            Ensure    = 'Present'
            DependsOn = "[WindowsFeature]AD-Domain-Services"
        }

        xADDomain FirstDC
        {
            DomainName                    = "bvbamoos.local"
            DomainNETBIOSName             = "BVBAMOOS"
            DomainAdministratorCredential = $domainCred
            SafemodeAdministratorPassword = $safemodeAdministratorCred
            DatabasePath                  = 'C:\NTDS'         
            LogPath                       = 'C:\NTDS' 
            DependsOn                     = "[WindowsFeature]ADDSInstall"
        }

     

    }#Node

}#Config Closing

#AD Config

$ADConfig = @{
    AllNodes = @(
        @{
            NodeName                    = "localhost"
            Role                        = "Primary DC"
            DomainName                  = "bvbamoos.local"
            RetryCount                  = 20
            RetryIntervalSec            = 30
            PsDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
        }
    )
}

NewDomain -ConfigurationData $ADConfig `
    -safemodeAdministratorCred (Get-Credential -UserName '(Administrator)'  `
        -Message "New Domain Safe Mode Administrator Password") `
    -domainCred (Get-Credential -UserName bvbamoos.local\administrator `
        -Message "New Domain Admin Credential") `
   
  
    


Set-DscLocalConfigurationManager -Path .\NewDomain -Verbose -Force
