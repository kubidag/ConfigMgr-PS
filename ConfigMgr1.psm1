$LogFile = "K:\PreLoad\Preload.log"



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
    Publish-CMPrestageContent -DeploymentPackageId $SUPPkgIDs -DistributionPointName $DPName -FileName "$($PreLoadPath)Update.pkgx"     
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