## Passo 1

#Function to Set versioning limit on all lists in a web
Function Set-PnPVersionHistoryLimit
{
    param
    (
        [Parameter(Mandatory=$true)] $Web,
        [parameter(Mandatory=$false)][int]$VersioningLimit = 10
    )
     
    Try {
        Write-host "Processing Web:"$Web.URL -f Yellow
        Connect-PnPOnline -Url $Web.URL -Interactive
 
        #Array to exclude system libraries
        $SystemLibraries = @("Form Templates", "Pages", "Preservation Hold Library","Site Assets", "Site Pages", "Images",
                            "Site Collection Documents", "Site Collection Images","Style Library")
         
        $Lists = Get-PnPList -Includes BaseType, Hidden, EnableVersioning
        #Get All document libraries
        $DocumentLibraries = $Lists | Where {$_.BaseType -eq "DocumentLibrary" -and $_.Hidden -eq $False -and $_.Title -notin $SystemLibraries}
         
        #Set Versioning Limits
        ForEach($Library in $DocumentLibraries)
        {
            #powershell to set limit on version history
            If($Library.EnableVersioning)
            {
                #Set versioning limit
                Set-PnPList -Identity $Library -MajorVersions $VersioningLimit
                Write-host -f Green "`tVersion History Settings has been Updated on '$($Library.Title)'"
            }
            Else
            {
                Write-host -f Yellow "`tVersion History is turned-off at '$($Library.Title)'"
            }
        }
    }
    Catch {
        Write-host -f Red "Error:" $_.Exception.Message
    }
}



## Passo 2
#Parameters
$SiteURL ="https://crescent.sharepoint.com/sites/marketing"
     
#Connect to PnP Online
Connect-PnPOnline -URL $SiteURL -Interactive
 
#Get webs of the Site Collection
$Webs = Get-PnPSubWeb -Recurse -IncludeRootWeb
  
ForEach($Web in $Webs)
{
    Set-PnPVersionHistoryLimit -Web $Web
}
