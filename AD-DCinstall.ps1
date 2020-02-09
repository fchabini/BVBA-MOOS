Configuration NewDomain 

{


    param(

    

        [parameter(Mandatory = $true)]
        [pscredential]$domainCred,

        [parameter(Mandatory = $true)]
        [pscredential]$safemodeAdministratorCred

    )

    Import-Module PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xNetworking
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
            InterfaceAlias = "Ethernet"
            AddressFamily  = "IPV4"
        }

        xDefaultGatewayAddress DefaultGateway {
            Address        = $Node.DefaultGateway
            InterfaceAlias = $Node.InterfaceAlias
            AddressFamily  = "IPV4"
        }
        WindowsFeature DHCP {
            DependsOn            = '[xIPAddress]NewIpAddress'
            Name                 = 'DHCP'
            Ensure               = 'PRESENT'
            IncludeAllSubFeature = $true                                                                                                                              
 
        }  
        xDhcpServerScope Scope {
            IPStartRange  = "192.168.0.223"
            IPEndRange    = "192.168.0.227"
            Name          = "TestScope1"
            SubnetMask    = "255.255.255.240"
            State         = "Active"            
            Ensure        = "Present"
            LeaseDuration = "7:00:00"
            DependsOn     = "[WindowsFeature]DHCP"
            
        }
 
        WindowsFeature DNS { 
            Ensure = "Present" 
            Name   = "DNS"
        }

        xDnsServerAddress DnsServerAddress { 
            Address        = '127.0.0.1' 
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            DependsOn      = "[WindowsFeature]DNS"
        }

        File ADFiles {
            DestinationPath = 'C:\NTDS'
            Type            = 'Directory'
            Ensure          = 'Present'
        }
     
        WindowsFeature ADDSInstall {
            Ensure = "Present"
            Name   = "AD-Domain-Services"
        }

        WindowsFeature ADDSTools {
            Ensure = 'Present'
            Name   = 'RSAT-ADDS'
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
