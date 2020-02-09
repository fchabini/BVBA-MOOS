Configuration NewDomain 

{


param(

    

    [parameter(Mandatory=$true)]
    [pscredential]$domainCred,

    [parameter(Mandatory=$true)]
    [pscredential]$safemodeAdministratorCred

)

Import-Module PSDesiredStateConfiguration
Import-DscResource -ModuleName xActiveDirectory
Import-DscResource –ModuleName PSDesiredStateConfiguration


Node $AllNodes.Where{$_.Role -eq "Primary DC"}.NodeName
    {
      LocalConfigurationManager
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

      File ADFiles
        {
            DestinationPath = 'C:\NTDS'
            Type = 'Directory'
            Ensure = 'Present'
        }
     
      WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

      WindowsFeature ADDSTools
        {
            Ensure='Present'
            Name = 'RSAT-ADDS'
        }

      xADDomain FirstDC
        {
            DomainName = "bvbamoos.local"
            DomainNETBIOSName = "BVBAMOOS"
            DomainAdministratorCredential = $domainCred
            SafemodeAdministratorPassword = $safemodeAdministratorCred
            DatabasePath = 'C:\NTDS'         
            LogPath = 'C:\NTDS' 
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

    }#Node

}#Config Closing

#AD Config

$ADConfig = @{
    AllNodes = @(
        @{
            NodeName = "localhost"
            Role = "Primary DC"
            DomainName = "bvbamoos.local"
            RetryCount = 20
            RetryIntervalSec = 30
            PsDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
         }
    )
}

NewDomain -ConfigurationData $ADConfig `
    -safemodeAdministratorCred (Get-Credential -UserName '(Administrator)'  `
        -Message "New Domain Safe Mode Administrator Password") `
    -domainCred (Get-Credential -UserName bvbamoos.local\administrator `
        -Message "New Domain Admin Credential") `

Set-DscLocalConfigurationManager -Path .\NewDomain -Verbose -Force
