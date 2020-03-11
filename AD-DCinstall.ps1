Configuration NewDomain 

{


    param(

    

        [parameter(Mandatory = $true)]
        [pscredential]$domainCred,

        [parameter(Mandatory = $true)]
        [pscredential]$safemodeAdministratorCred,
        
        [parameter(Mandatory = $true)]
        [pscredential]$passwordCred  

    


    )

    # Install and import all the needed Modules in/from C:\Program Files\WindowsPowerShell\Modules 

    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xdhcpserver
    Import-DscResource -ModuleName xSmbShare 

    # Configuration of our first primary server DC01

    Node $AllNodes.NodeName
    {
        LocalConfigurationManager {
            ActionAfterReboot  = 'ContinueConfiguration'
            ConfigurationMode  = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
    # setting static IP and Neetmask for IPV4 AddressFamilly 

        xIPAddress NewIPAddress
        {
            IPAddress      = "192.168.2.220/24"
            InterfaceAlias = 'Ethernet'
            AddressFamily  = "IPV4"
           
        }
     # setting up our DefaultGateway Addresse  

        xDefaultGatewayAddress DefaultGateway
        {
            Address        = "192.168.2.1"
            InterfaceAlias = 'Ethernet'
            AddressFamily  = "IPV4"
        }

     # installing the DNS Feature, tools and the DNS server Addresse 

         WindowsFeature DNS { 
            Ensure = "Present" 
            Name   = "DNS"
           
        }

        xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' ,'192.168.2.220' 
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            DependsOn      = "[WindowsFeature]DNS"
        }

        WindowsFeature DNSTools {
            Ensure = "Present"
            Name = 'RSAT-DNS-Server'
            DependsOn = '[WindowsFeature]DNS'
        }

     # installing the DHCP Feature, tools and the DHCP server Scope bvbaMoosscope

        WindowsFeature DHCP {
            DependsOn            = '[xIPAddress]NewIpAddress'
            Name                 = 'DHCP'
            Ensure               = 'PRESENT'
            IncludeAllSubFeature = $true                                                                                                                              
     
        }

     
        WindowsFeature DHCPTools
        {
            Ensure = "Present"
            Name = 'RSAT-DHCP'
            DependsOn = '[WindowsFeature]DHCP'
        }
	

        xDhcpServerScope Scope
        {
            ScopeID = "192.168.2.0"
            IPStartRange = "192.168.2.221"
            IPEndRange = "192.168.2.225"
	    Ensure = "Present"
            Name = "BvbaMOOSscope"
            SubnetMask = "255.255.255.0"
            State = "Active"         
            LeaseDuration = "8:00:00"
            DependsOn = "[WindowsFeature]DHCP"
        
        }
        xDhcpServerOption ServerOpt
        {
            ScopeID = "192.168.2.0"
            Router = "192.168.2.1"
            DnsServerIPAddress = "192.168.2.220"
            DnsDomain = "bvbvamoos.local"
            AddressFamily = "IPv4"            
            Ensure = "Present"
            DependsOn = "[xDhcpServerScope]Scope"
        }

      # Authorizing our DHCP Scope 

        xDhcpServerAuthorization DhcpAuth
        {
            Ensure = "Present"
            DependsOn = "[WindowsFeature]DHCP"
        }
      
      # installing the Active directory Domain serverices, Rsat Dns Server
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

       # creating and setting up our Active Directory database directory 

        File ADFiles {
            DestinationPath = 'C:\NTDS'
            Type            = 'Directory'
            Ensure          = 'Present'
        }

       # installing the Rsat tools for Active Directory 

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
       # Installing our webserver, Mgmt tools and scripting tools  

        WindowsFeature IIS {
            Ensure = 'Present'
            Name   = 'Web-Server'
        }

        WindowsFeature IISConsole {
            Ensure    = 'Present'
            Name      = 'Web-Mgmt-Console'
            DependsOn = '[WindowsFeature]IIS'
        }

        WindowsFeature IISScriptingTools {
            Ensure    = 'Present'
            Name      = 'Web-Scripting-Tools'
            DependsOn = '[WindowsFeature]IIS'
        }

       # creating an html index with a welcome message 

        File Indexfile {
            Ensure          = 'Present'
            Type            = 'file'
            DestinationPath = "C:\inetpub\wwwroot\index.html"
            Contents        = "<html>
            <header><title>Welkom</title></header>
                <body>
                        Faycal Chabini welcomes you to his first webserver and is proud to have writen this DSC script 
                </body>
            </html>"
        }
       # Adding a new Firewall rule that allows traffic to and from our webserver 

        xFirewall IISinboundwebserviceshttpTCP
        {
            Name        = "IISinboundwebserviceshttpTCP"
            Ensure      = "Present"
            Direction   = "inbound"
            Description = "allow HTTP traffic for Internet Information Services (IIS) [TCP 80]"
            Profile     = "Domain"
            Protocol    = "TCP"
            LocalPort   = ("80")
            Action      = "Allow"
            Enabled     = "True"
        }
       # Creating a local Admin user 

        User LocalAdmin {
            UserName                 = "faycal"
            FullName                 = "faycal chabini"
            Ensure                   = 'Present'
            Password                 = $passwordCred
            Description              = 'User created by DSC'
            PasswordNeverExpires     = $true
            PasswordChangeNotAllowed = $true
        }

       # Creating all our groups and adding our user faycal as a member to all of them 

        Group Marketing {
            GroupName = 'GRmarketing'
            Ensure    = 'Present'
            Members   = @( 'faycal' )
        }

        Group HR {
            GroupName = 'GRHR'
            Ensure    = 'Present'
            Members   = @( 'faycal' )
        }

        Group Production {
            GroupName = 'GRProduction'
            Ensure    = 'Present'
            Members   = @( 'faycal' )
        }

        Group Logistics {
            GroupName = 'GRLogistics'
            Ensure    = 'Present'
            Members   = @( 'faycal' )
        }

        Group Research {
            GroupName = 'GRResearch'
            Ensure    = 'Present'
            Members   = @( 'faycal' )
        }

      # Creating and sharing all our Shared folders for all the needed dpts # Adding all our previsouly created groups the membership of these shares 

        File Share {
            Ensure          = "present"
            DestinationPath = "c:\share"
            Type            = "Directory"
        }
        
        File Marketing {
            Ensure          = "present"
            DestinationPath = "c:\share\Marketing"
            Type            = "Directory"
            
        }

        File HR {
            Ensure          = "present"
            DestinationPath = "c:\share\HR"
            Type            = "Directory"
            
        }

        File Production {
            Ensure          = "present"
            DestinationPath = "c:\share\Production"
            Type            = "Directory"
            
        }
 
        File Logistics {
            Ensure          = "present"
            DestinationPath = "c:\share\Logistics"
            Type            = "Directory"
            
        }

        File Research {
            Ensure          = "present"
            DestinationPath = "c:\share\Research"
            Type            = "Directory"
            
        }

       # Adding all our previsouly created groups the membership of these shares 

        xSmbShare Marketing 
        { 
            Ensure       = "Present"  
            Name         = "Marketing" 
            Path         = "C:\share\Marketing"  
            ChangeAccess = "GRmarketing"           
            Description  = "This is an updated description for this share" 
        } 

        xSmbShare HR 
        { 
            Ensure       = "Present"  
            Name         = "HR" 
            Path         = "C:\share\HR"
            ChangeAccess = "GRHR"     
            Description  = "This is an updated description for this share" 
        } 

        xSmbShare Production
        { 
            Ensure       = "Present"  
            Name         = "Production" 
            Path         = "C:\share\Production"           
            ChangeAccess = "GRproduction"  
            Description  = "This is an updated description for this share" 
        } 

        xSmbShare Logistics 
        { 
            Ensure       = "Present"  
            Name         = "Logistics" 
            Path         = "C:\share\logistics"  
            ChangeAccess = "GRlogistics"    
            Description  = "This is an updated description for this share" 
        } 
        xSmbShare Research
        { 
            Ensure       = "Present"  
            Name         = "Research" 
            Path         = "C:\share\Research"  
            ChangeAccess = "GRresearch"            
            Description  = "This is an updated description for this share" 
        } 
        

       # Adding our first domain  bvbamoos.local 

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

# Creating and securing/incripting our usernames and passwords for our creds through Clixml



$safemodeAdministratorCred = Import-Clixml -path C:\creds\tenant.xml
$domaincred = Import-Clixml -Path C:\creds\tenantdomain.xml
$password = Import-Clixml -Path C:\creds\tenantuser.xml

#creating our Mof file 

Set-DscLocalConfigurationManager -Path .\Newdomain -Verbose -Force


# Starting the DscConfiguration 
 
Start-DscConfiguration -Wait -Force -Verbose .\Newdomain 