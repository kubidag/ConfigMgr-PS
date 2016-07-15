

function New-CMSite {

[CmdletBinding()]
    PARAM
    (
        [Parameter(Mandatory=$true)] $SiteCode,
        [Parameter(Mandatory=$true)] $SiteServer,
        [Parameter(Mandatory=$true)] $ModulePath
        
    )
    Import-Module $ModulePath"\ConfigurationManager.psd1" -Force -Global
    New-PSDrive -Name $SiteCode -PSProvider "CMSite" -Root $SiteServer -Scope Global
    Set-Location $SiteCode":"
}






Function New-Log {

##########################################################################################################
<#
.SYNOPSIS
   Log to a file in a format that can be read by Trace32.exe / CMTrace.exe 

.DESCRIPTION
   Write a line of data to a script log file in a format that can be parsed by Trace32.exe / CMTrace.exe

   The severity of the logged line can be set as:

        1 - Information
        2 - Warning
        3 - Error

   Warnings will be highlighted in yellow. Errors are highlighted in red.

   The tools to view the log:

   SMS Trace - http://www.microsoft.com/en-us/download/details.aspx?id=18153
   CM Trace - Installation directory on Configuration Manager 2012 Site Server - <Install Directory>\tools\

.EXAMPLE
   Log-ScriptEvent c:\output\update.log "Application of MS15-031 failed" Apply_Patch 3

   This will write a line to the update.log file in c:\output stating that "Application of MS15-031 failed".
   The source component will be Apply_Patch and the line will be highlighted in red as it is an error 
   (severity - 3).

#>
##########################################################################################################

#Define and validate parameters
[CmdletBinding()]
Param(
      #Path to the log file
      [parameter(Mandatory=$True)]
      [String]$NewLog,

      #The information to log
      [parameter(Mandatory=$True)]
      [String]$Value,

      #The source of the error
      [parameter(Mandatory=$True)]
      [String]$Component,

      #The severity (1 - Information, 2- Warning, 3 - Error)
      [parameter(Mandatory=$True)]
      [ValidateRange(1,3)]
      [Single]$Severity
      )


#Obtain UTC offset
$DateTime = New-Object -ComObject WbemScripting.SWbemDateTime 
$DateTime.SetVarDate($(Get-Date))
$UtcValue = $DateTime.Value
$UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21)


#Create the line to be logged
$LogLine =  "<![LOG[$Value]LOG]!>" +`
            "<time=`"$(Get-Date -Format HH:mm:ss.fff)$($UtcOffset)`" " +`
            "date=`"$(Get-Date -Format M-d-yyyy)`" " +`
            "component=`"$Component`" " +`
            "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +`
            "type=`"$Severity`" " +`
            "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " +`
            "file=`"`">"

#Write the line to the passed log file
Add-Content -Path $NewLog -Value $LogLine
Write-Host $Value

}

##########################################################################################################




function Publish-PreloadPackages {

[CmdletBinding()]
    PARAM
    (
        [Parameter(Mandatory=$true)] $SiteCode,
        [Parameter(Mandatory=$true)] $SiteServer,
        [Parameter(Mandatory=$true)] $DPName,
        [Parameter(Mandatory=$true)] $PreLoadPath,
        [Parameter(ValueFromPipelineByPropertyName=$true, Mandatory=$true)] $DPGroupID
    )


#Value	Description
#2	SMS_Package
#14	SMS_OperatingSystemInstallPackage
#18	SMS_ImagePackage
#19	SMS_BootImagePackage
#23	SMS_DriverPackage
#24	SMS_SoftwareUpdatesPackage
#31	SMS_Application

Set-Location "$($SiteCode):"

$PackageIDs
$OSInstallPkgIDs
$OSImageIDs
$BootImageIDs
$DriverPkgIDs
$SUPPkgIDs
$AppsIDs

$i = 0

New-Log $LogFile "Connecting SMS_DPGroupContentInfo class..." Preload 1
$DPGroupPackages = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_DPGroupContentInfo -ComputerName $SiteServer
$DPGroupPackages | Select-Object Name,PackageID,SourceSize,ObjectTypeID | ft -AutoSize | Out-File $("$PreLoadPath\ExportePkgs.txt")


#2	SMS_Package
$PackageIDs = $DPGroupPackages | Where-Object -Property ObjectTypeID -eq 2 | Select-Object -ExpandProperty PackageID
#14	SMS_OperatingSystemInstallPackage
$OSInstallPkgIDs = $DPGroupPackages | Where-Object -Property ObjectTypeID -eq 14 | Select-Object -ExpandProperty PackageID
#18	SMS_ImagePackage
$OSImageIDs = $DPGroupPackages | Where-Object -Property ObjectTypeID -eq 18 | Select-Object -ExpandProperty PackageID
#19	SMS_BootImagePackage
$BootImageIDs = $DPGroupPackages | Where-Object -Property ObjectTypeID -eq 19 | Select-Object -ExpandProperty PackageID
#23	SMS_DriverPackage
$DriverPkgIDs = $DPGroupPackages | Where-Object -Property ObjectTypeID -eq 23 | Select-Object -ExpandProperty PackageID
#24	SMS_SoftwareUpdatesPackage
$SUPPkgIDs = $DPGroupPackages | Where-Object -Property ObjectTypeID -eq 24 | Select-Object -ExpandProperty PackageID
#31	SMS_Application
$AppNames = $DPGroupPackages | Where-Object -Property ObjectTypeID -eq 31 | Select-Object -ExpandProperty Name



if ($PackageIDs -ne $null)
{
    Publish-CMPrestageContent -PackageIds $PackageIDs -DistributionPointName $DPName -FileName "$($PreLoadPath)Packages.pkgx"  
}
else
{
    New-Log $LogFile "No legacy packages were found, skipping" Preload 2 
}

if ($OSInstallPkgIDs -ne $null)
{
    Publish-CMPrestageContent -OperatingSystemInstallerIds $OSInstallPkgIDs -DistributionPointName $DPName -FileName "$($PreLoadPath)OSInstaller.pkgx"   
}
else
{
    New-Log $LogFile "No OS Installer pacakges were found, skipping" Preload 2 
}

if ($OSImageIDs -ne $null)
{
    Publish-CMPrestageContent -OperatingSystemImageIds $OSImageIDs -DistributionPointName $DPName -FileName "$($PreLoadPath)OSImage.pkgx"   
}
else
{
    New-Log $LogFile "No OS Image packages were found, skipping" Preload 2 
}

if ($BootImageIDs -ne $null)
{
    Publish-CMPrestageContent -BootImageIds $BootImageIDs -DistributionPointName $DPName -FileName "$($PreLoadPath)BootImages.pkgx"   
}
else
{
    New-Log $LogFile "No Boot Images were found, skipping" Preload 2 
}

if ($DriverPkgIDs -ne $null)
{
    Publish-CMPrestageContent -DriverPackageIds $DriverPkgIDs -DistributionPointName $DPName -FileName "$($PreLoadPath)Drivers.pkgx"    
}
else
{
    New-Log $LogFile "No driver packages were found, skipping" Preload 2 
}

if ($SUPPkgIDs -ne $null)
{
    Publish-CMPrestageContent -DeploymentPackageIds $SUPPkgIDs -DistributionPointName $DPName -FileName "$($PreLoadPath)Update.pkgx"     
}
else
{
    New-Log $LogFile "No driver packages were found, skipping" Preload 2 
}

if ($AppNames -ne $null)
{
    Publish-CMPrestageContent -ApplicationNames $AppNames -DistributionPointName $DPName -FileName "$($PreLoadPath)Applications.pkgx"   
}
else
{
    New-Log $LogFile "No driver packages were found, skipping" Preload 2 
}


Clear-Variable -Name PackageIDs,OSInstallPkgIDs,OSImageIDs,BootImageIDs,DriverPkgIDs,SUPPkgIDs,AppsIDs -ErrorAction SilentlyContinue

}


function New-CMDP {

[CmdletBinding()]
    PARAM
    (
        [Parameter(Mandatory=$true)] $SiteCode,
        [Parameter(Mandatory=$true)] $SiteServer,
        [Parameter(Mandatory=$true)] $DPName,
        [Parameter(Mandatory=$true)] $ModulePath,
        [Parameter(Mandatory=$false)] 
        [ValidateSet("Pull", "Standard")]
        $DPType,
        [Parameter(Mandatory=$false)] $SourceDPs,
        [Parameter(Mandatory=$false)] $DPGroupName

    )
    try
    {
        #Write-Host $SiteCode $SiteServer $DPName $ModulePath
        New-Log $LogFile "Connecting Site: $SiteCode SiteServer: $SiteServer" InstallDP 1
        New-CMSite -SiteCode $SiteCode -SiteServer $SiteServer -ModulePath $ModulePath
        #New-Log $LogFile "Changing location to site: $SiteCode" InstallDP 1
        #Set-Location $SiteCode":"
        New-Log $LogFile "Adding new site system: $DPName" InstallDP 1
        New-CMSiteSystemServer -SiteCode $SiteCode -SiteSystemServerName $DPName
        New-Log $LogFile "Adding DP Role on $DPName" InstallDP 1
        If ($DPType -contains "Pull") 
        {
            New-Log $LogFile "Pull DP option has been selected" InstallDP 1
            Add-CMDistributionPoint -SiteSystemServerName $DPName -SiteCode $SiteCode -ClientConnectionType Intranet -MinimumFreeSpaceMB 10000 `
                            -PrimaryContentLibraryLocation K -SecondaryContentLibraryLocation Automatic -PrimaryPackageShareLocation K -SecondaryPackageShareLocation Automatic `
                            -EnablePxeSupport -AllowRespondIncomingPxeRequest -EnableUnknownComputerSupport -UserDeviceAffinity AllowWithAutomaticApproval -PxeServerResponseDelaySec 10 `
                            -CertificateExpirationTimeUtc ((Get-Date).AddYears(100)) -ComputersUsePxePassword (Get-Content $ModulePath"\Encrypted.txt" | ConvertTo-SecureString -Key (1..16)) `
                            -EnablePullDP -SourceDistributionPoint ($SourceDPs -split ",") `
                            -ErrorAction Stop -Verbose
        }
        Else
        {
            New-Log $LogFile "Standard DP option has been selected" InstallDP 1
            Add-CMDistributionPoint -SiteSystemServerName $DPName -SiteCode $SiteCode -ClientConnectionType Intranet -MinimumFreeSpaceMB 10000 `
                            -PrimaryContentLibraryLocation K -SecondaryContentLibraryLocation Automatic -PrimaryPackageShareLocation K -SecondaryPackageShareLocation Automatic `
                            -EnablePxeSupport -AllowRespondIncomingPxeRequest -EnableUnknownComputerSupport -UserDeviceAffinity AllowWithAutomaticApproval -PxeServerResponseDelaySec 10 `
                            -CertificateExpirationTimeUtc ((Get-Date).AddYears(100)) -ComputersUsePxePassword (Get-Content $ModulePath"\Encrypted.txt" | ConvertTo-SecureString -Key (1..16)) `
                            -ErrorAction Stop
        }
        $DP =  Get-CMDistributionPoint -SiteSystemServerName $DPName -ErrorAction Stop
        New-log $LogFile "Disabling fallback for the DP: $DPName" InstallDP 1
        $DP | Set-CMDistributionPoint -AllowFallbackForContent $False -ErrorAction Stop
        If ($DPGroupName)
        {
            New-Log $LogFile "DP Group is specified adding server $DPName to DP Group $DPGroupName" InstallDP 1
            #something's going on here, Let's sleep for 30 secs
            Start-Sleep -Seconds 30
            $DP | Add-CMDistributionPointToGroup -DistributionPointGroupName $DPGroupName -Verbose
        }

    }
    catch
    {
        New-Log $LogFile "Error creating the DP role: $_" InstallDP 3
        Break
    }


}

Function Publish-FailedPkgs
{

[CmdletBinding()]
    PARAM
    (
        [Parameter(Mandatory=$true)] $SiteCode,
        [Parameter(Mandatory=$true)] $SiteServer,
        [Parameter(Mandatory=$true)] $DPName
    )
    #$LogFile = "C:\temp\test.log"
    New-Log $LogFile "Connecting SMS_DistributionDPStatus..." PublishFailedPackages 1
    #get list of failed content
    $DPDistStatus = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_DistributionDPStatus -ComputerName $SiteServer -Filter "MessageState=2 AND Name='$DPName'"
    If ($DPDistStatus)
    {
        New-Log $LogFile "Failed packages detected!" PublishFailedPackages 1
        New-Log $LogFile "Connecting SMS_DistributionPoint class..." PublishFailedPackages 1
        $DP = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_DistributionPoint -ComputerName $SiteServer -Filter "ServerNALPath LIKE '%$DPName%'"
        Foreach ($objDPstat in $DPDistStatus)
        {
            Foreach ($objDP in $DP)
	        {
		        if ($objDP.PackageID -eq $objDPstat.PackageID)
		        {
			        New-Log $LogFile "Redistributing package: $($objDPStat.PackageID)" PublishFailedPackages 1
			        $objDP.RefreshNow = $true
			        $objDP.Put()	
		        }
	        }
        }
    }
    else
    {
        New-Log $LogFile "No failed packages found on this DP" PublishFailedPackages 1
    }
}


Function Watch-ContentStatus
{

[CmdletBinding()]
    PARAM
    (
        [Parameter(Mandatory=$true)] $SiteCode,
        [Parameter(Mandatory=$true)] $SiteServer,
        [Parameter(Mandatory=$true)] $DPName,
        [Parameter(Mandatory=$true)] $DPGroupName
    )

    New-Log $LogFile "Connecting SMS_DPStatusInfo class..." MonitorContent 1
    $DPStatus = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_DPStatusInfo -ComputerName $SiteServer -Filter "name='$DPName'"
    New-Log $LogFile "Connecting SMS_PackageStatusDistPointsSummarizer class..." MonitorContent 1
    $DPSumm = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_PackageStatusDistPointsSummarizer -ComputerName $SiteServer -Filter "ServerNALPath LIKE '%$DPName%'"
    $DPGroupInfo = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_DPGroupInfo -ComputerName $SiteServer -Filter "name='$DPGroupName'"
    New-Log $LogFile "$DPGroupName has total of $($DPGroupInfo.AssignedContentCount) content distributed" MonitorContent 1
    $TotalPackages = $DPStatus.NumberErrors + $DPStatus.NumberInProgress + $DPStatus.NumberInstalled + $DPStatus.NumberUnknown
    New-Log $LogFile "Currently total packages targeted to DP: $TotalPackages" MonitorContent 1
    while ($TotalPackages -lt $DPGroupInfo.AssignedContentCount)
    {
        New-Log $LogFile "Total package count:$TotalPackages is less than $($DPGroupInfo.AssignedContentCount)" MonitorContent 1
        New-Log $LogFile "Wait for 30 sec..." MonitorContent 1
        Start-Sleep -Seconds 30
        $DPStatus = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_DPStatusInfo -ComputerName $SiteServer -Filter "name='$DPName'"
        $TotalPackages = $DPStatus.NumberErrors + $DPStatus.NumberInProgress + $DPStatus.NumberInstalled + $DPStatus.NumberUnknown
    }
    if ($DPStatus.NumberErrors -gt 0)
    {
        Publish-FailedPkgs -SiteCode $SiteCode -SiteServer $SiteServer -DPName $DPName  
    }
    while ($DPStatus.NumberInstalled -lt $TotalPackages)
    {
        #New-Log $LogFile "Content distribution is in progress. Count inprogress:$($DPStatus.NumberInProgress). Sleeping 10 minutes..." MonitorContent 1
        New-Log $LogFile "Installed content is less than the assigned content: Installed:$($DPStatus.NumberInstalled), Assigned: $($DPGroupInfo.AssignedContentCount). Waiting for 30 seconds... " MonitorContent 1
        New-Log $LogFile "Looks like the content distributed to the DP Group is not same as DP Status count" MonitorContent 1
        New-Log $LogFile "Assigned DP Group Content = $($DPGroupInfo.AssignedContentCount)" MonitorContent 1  
        $TotalPackages = $DPStatus.NumberErrors + $DPStatus.NumberInProgress + $DPStatus.NumberInstalled + $DPStatus.NumberUnknown
        New-Log $LogFile "DP Status: Errors:$($DPStatus.NumberErrors) , InProgress:$($DPStatus.NumberInProgress) , Installed:$($DPStatus.NumberInstalled) , Unknown:$($DPStatus.NumberUnknown), Total:$TotalPackages " MonitorContent 1
        if ($DPGroupInfo.AssignedContentCount -lt $TotalPackages)
        {
            New-Log $LogFile "Total content distributed to the DP is more than the assigned content to DP group, difference most likely caused by automatically distributed client install packages or content distribution directly to DP" MonitorContent 1
        }
        Start-Sleep -Seconds 30
        $DPStatus = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_DPStatusInfo -ComputerName $SiteServer -Filter "name='$DPName'"
        
    }
    New-Log $LogFile "Installed Packages: $($DPStatus.NumberInstalled), Total Packages: $TotalPackages" MonitorContent 1
    New-Log $LogFile "No packages are in progress" MonitorContent 1
}