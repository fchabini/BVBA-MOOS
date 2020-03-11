[DSCLocalConfigurationManager()]
configuration LCMBVBAMOOS
{
    Node localhost
    {
        Settings
        {
            RefreshMode = 'Push'
            RebootNodeIfNeeded = $True
RefreshFrequencyMins =             30
ConfigurationMode = 'ApplyAndAutoCorrect'

        }
    }
}
LCMBVBAMOOS

LCMBVBAMOOS -outputpath "C:\Users\Administrator\NewDomain\Localhostconfig"
Set-DscLocalConfigurationManager -Path "C:\Users\Administrator\NewDomain\Localhostconfig"