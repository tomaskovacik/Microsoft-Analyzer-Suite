﻿# MFA-Analyzer
#
# @author:    Martin Willing
# @copyright: Copyright (c) 2025 Martin Willing. All rights reserved. Licensed under the MIT license.
# @contact:   Any feedback or suggestions are always welcome and much appreciated - mwilling@lethal-forensics.com
# @url:       https://lethal-forensics.com/
# @date:      2025-02-24
#
#
# ██╗     ███████╗████████╗██╗  ██╗ █████╗ ██╗      ███████╗ ██████╗ ██████╗ ███████╗███╗   ██╗███████╗██╗ ██████╗███████╗
# ██║     ██╔════╝╚══██╔══╝██║  ██║██╔══██╗██║      ██╔════╝██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║██╔════╝██╔════╝
# ██║     █████╗     ██║   ███████║███████║██║█████╗█████╗  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║███████╗██║██║     ███████╗
# ██║     ██╔══╝     ██║   ██╔══██║██╔══██║██║╚════╝██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║╚██╗██║╚════██║██║██║     ╚════██║
# ███████╗███████╗   ██║   ██║  ██║██║  ██║███████╗ ██║     ╚██████╔╝██║  ██║███████╗██║ ╚████║███████║██║╚██████╗███████║
# ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝ ╚═════╝╚══════╝
#
#
# Dependencies:
#
# ImportExcel v7.8.10 (2024-10-21)
# https://github.com/dfinke/ImportExcel
#
#
# Tested on Windows 10 Pro (x64) Version 22H2 (10.0.19045.5487) and PowerShell 5.1 (5.1.19041.5486)
# Tested on Windows 10 Pro (x64) Version 22H2 (10.0.19045.5487) and PowerShell 7.5.0
#
#
#############################################################################################################################################################################################
#############################################################################################################################################################################################

<#
.SYNOPSIS
  MFA-Analyzer - Automated Analysis of Authentication Methods and User Registration Details for DFIR

.DESCRIPTION
  MFA-Analyzer.ps1 is a PowerShell script utilized to simplify the analysis of the MFA Status of all users extracted via "Microsoft Extractor Suite" by Invictus Incident Response.

  https://github.com/invictus-ir/Microsoft-Extractor-Suite (Microsoft-Extractor-Suite v3.0.2)

  https://microsoft-365-extractor-suite.readthedocs.io/en/latest/functionality/Azure/GetUserInfo.html#retrieves-mfa-status

.PARAMETER OutputDir
  Specifies the output directory. Default is "$env:USERPROFILE\Desktop\MFA-Analyzer".

  Note: The subdirectory 'MFA-Analyzer' is automatically created.

.PARAMETER Path
  Specifies the path to the CSV-based input file (*-AuthenticationMethods.csv).

.EXAMPLE
  PS> .\MFA-Analyzer.ps1

.EXAMPLE
  PS> .\MFA-Analyzer.ps1 -Path "$env:USERPROFILE\Desktop\*-AuthenticationMethods.csv"

.EXAMPLE
  PS> .\MFA-Analyzer.ps1 -Path "H:\Microsoft-Extractor-Suite\*-AuthenticationMethods.csv" -OutputDir "H:\Microsoft-Analyzer-Suite"

.NOTES
  Author - Martin Willing

.LINK
  https://lethal-forensics.com/
#>

#############################################################################################################################################################################################
#############################################################################################################################################################################################

#region CmdletBinding

[CmdletBinding()]
Param(
    [String]$Path,
    [String]$OutputDir
)

#endregion CmdletBinding

#############################################################################################################################################################################################
#############################################################################################################################################################################################

#region Declarations

# Declarations

# Output Directory
if (!($OutputDir))
{
    $script:OUTPUT_FOLDER = "Output\MFA-Analyzer" # Default
}
else
{
    if ($OutputDir -cnotmatch '.+(?=\\)') 
    {
        Write-Host "[Error] You must provide a valid directory path." -ForegroundColor Red
        Exit
    }
    else
    {
        $script:OUTPUT_FOLDER = "$OutputDir\MFA-Analyzer" # Custom
    }
}

#endregion Declarations

#############################################################################################################################################################################################
#############################################################################################################################################################################################

#region Header

# Check if the PowerShell script is being run with admin rights
if($isWindows){
if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host "[Error] This PowerShell script must be run with admin rights." -ForegroundColor Red
    $Host.UI.RawUI.WindowTitle = "$DefaultWindowsTitle"
    Exit
}
}

# Check if PowerShell module 'ImportExcel' is installed
if (!(Get-Module -ListAvailable -Name ImportExcel))
{
    Write-Host "[Error] Please install 'ImportExcel' PowerShell module." -ForegroundColor Red
    Write-Host "[Info]  Check out: https://github.com/evild3ad/Microsoft-Analyzer-Suite/wiki#setup"
    Exit
}

# Windows Title
if ($isWindows){
	$DefaultWindowsTitle = $Host.UI.RawUI.WindowTitle
	$Host.UI.RawUI.WindowTitle = "MFA-Analyzer - Automated Analysis of Authentication Methods and User Registration Details for DFIR"
}

# Flush Output Directory
if (Test-Path "$OUTPUT_FOLDER")
{
    Get-ChildItem -Path "$OUTPUT_FOLDER" -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse
    New-Item "$OUTPUT_FOLDER" -ItemType Directory -Force | Out-Null
}
else 
{
    New-Item "$OUTPUT_FOLDER" -ItemType Directory -Force | Out-Null
}

# Function Get-FileSize
Function Get-FileSize()
{
    Param ([long]$Length)
    If ($Length -gt 1TB) {[string]::Format("{0:0.00} TB", $Length / 1TB)}
    ElseIf ($Length -gt 1GB) {[string]::Format("{0:0.00} GB", $Length / 1GB)}
    ElseIf ($Length -gt 1MB) {[string]::Format("{0:0.00} MB", $Length / 1MB)}
    ElseIf ($Length -gt 1KB) {[string]::Format("{0:0.00} KB", $Length / 1KB)}
    ElseIf ($Length -gt 0) {[string]::Format("{0:0.00} Bytes", $Length)}
    Else {""}
}

# Select Log File
if(!($Path))
{
    Function Get-LogFile($InitialDirectory)
    { 
        [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.InitialDirectory = $InitialDirectory
        $OpenFileDialog.Filter = "Authentication Methods (*csv)|*-AuthenticationMethods.csv|All Files (*.*)|*.*"
        $OpenFileDialog.ShowDialog()
        $OpenFileDialog.Filename
        $OpenFileDialog.ShowHelp = $true
        $OpenFileDialog.Multiselect = $false
    }

    $Result = Get-LogFile

    if($Result -eq "OK")
    {
        $script:AuthenticationMethods = $Result[1]
    }
    else
    {
        $Host.UI.RawUI.WindowTitle = "$DefaultWindowsTitle"
        Exit
    }
}
else
{
    #$script:LogFile = $Path
    $script:AuthenticationMethods = $Path
}

# Create a record of your PowerShell session to a text file
Start-Transcript -Path "$OUTPUT_FOLDER\Transcript.txt"

# Get Start Time
$startTime = (Get-Date)

# Logo
$Logo = @"
██╗     ███████╗████████╗██╗  ██╗ █████╗ ██╗      ███████╗ ██████╗ ██████╗ ███████╗███╗   ██╗███████╗██╗ ██████╗███████╗
██║     ██╔════╝╚══██╔══╝██║  ██║██╔══██╗██║      ██╔════╝██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║██╔════╝██╔════╝
██║     █████╗     ██║   ███████║███████║██║█████╗█████╗  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║███████╗██║██║     ███████╗
██║     ██╔══╝     ██║   ██╔══██║██╔══██║██║╚════╝██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║╚██╗██║╚════██║██║██║     ╚════██║
███████╗███████╗   ██║   ██║  ██║██║  ██║███████╗ ██║     ╚██████╔╝██║  ██║███████╗██║ ╚████║███████║██║╚██████╗███████║
╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝ ╚═════╝╚══════╝
"@

Write-Output ""
Write-Output "$Logo"
Write-Output ""

# Header
Write-Output "MFA-Analyzer - Automated Analysis of Authentication Methods and User Registration Details for DFIR"
Write-Output "(c) 2025 Martin Willing at Lethal-Forensics (https://lethal-forensics.com/)"
Write-Output ""

# Analysis date (ISO 8601)
$AnalysisDate = [datetime]::Now.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
Write-Output "Analysis date: $AnalysisDate UTC"
Write-Output ""

#endregion Header

#############################################################################################################################################################################################
#############################################################################################################################################################################################

#region Analysis

# Input-Check
if (!(Test-Path "$AuthenticationMethods"))
{
    Write-Host "[Error] $AuthenticationMethods does not exist." -ForegroundColor Red
    Write-Host ""
    Stop-Transcript
    $Host.UI.RawUI.WindowTitle = "$DefaultWindowsTitle"
    Exit
}

# Check File Extension
$Extension = [IO.Path]::GetExtension($AuthenticationMethods)
if (!($Extension -eq ".csv" ))
{
    Write-Host "[Error] No CSV File provided." -ForegroundColor Red
    Stop-Transcript
    $Host.UI.RawUI.WindowTitle = "$DefaultWindowsTitle"
    Exit
}

# Processing Authentication Methods
Write-Output "[Info]  Processing Authentication Methods ..."
New-Item "$OUTPUT_FOLDER\CSV" -ItemType Directory -Force | Out-Null
New-Item "$OUTPUT_FOLDER\XLSX" -ItemType Directory -Force | Out-Null

# Input Size
$InputSize = Get-FileSize((Get-Item "$AuthenticationMethods").Length)
Write-Output "[Info]  Total Input Size: $InputSize"

# Count rows of CSV (w/ thousands separators)
$Count = 0
switch -File "$AuthenticationMethods" { default { ++$Count } }
$Rows = '{0:N0}' -f $Count
Write-Output "[Info]  Total Lines: $Rows"

# Authentication Methods

# CSV
if (Test-Path "$AuthenticationMethods")
{
    $Data = Import-Csv -Path "$AuthenticationMethods" -Delimiter ","

    $Results = [Collections.Generic.List[PSObject]]::new()
    ForEach($Record in $Data)
    {
        $Line = [PSCustomObject]@{
        "UserPrincipalName"                = $Record.user
        "MFA Status"                       = $Record.MFAstatus
        "Password"                         = $Record.password
        "Microsoft Authenticator"          = $Record.app
        "Phone"                            = $Record.phone
        "E-Mail"                           = $Record.email
        "FIDO2"                            = $Record.fido2
        "Software OATH"                    = $Record.softwareoath
        "Windows Hello for Business"       = $Record.hellobusiness
        "Temporary Access Pass"            = if([string]::IsNullOrEmpty($Record.temporaryAccessPassAuthenticationMethod)){"-"}else{$Record.temporaryAccessPassAuthenticationMethod}
        "Certificate-Based Authentication" = $Record.certificateBasedAuthConfiguration
        }

        $Results.Add($Line)
    }

    $Results | Export-Csv -Path "$OUTPUT_FOLDER\CSV\AuthenticationMethods.csv" -NoTypeInformation
}

# XLSX
if (Test-Path "$AuthenticationMethods")
{
    if(!([String]::IsNullOrWhiteSpace((Get-Content "$OUTPUT_FOLDER\CSV\AuthenticationMethods.csv"))))
    {
        $IMPORT = Import-Csv -Path "$OUTPUT_FOLDER\CSV\AuthenticationMethods.csv" -Delimiter "," -Encoding UTF8
        $IMPORT | Export-Excel -Path "$OUTPUT_FOLDER\XLSX\AuthenticationMethods.xlsx" -FreezeTopRow -BoldTopRow -AutoSize -AutoFilter -WorkSheetname "Authentication Methods" -CellStyleSB {
        param($WorkSheet)
        # BackgroundColor and FontColor for specific cells of TopRow
        $BackgroundColor = [System.Drawing.Color]::FromArgb(50,60,220)
        Set-Format -Address $WorkSheet.Cells["A1:K1"] -BackgroundColor $BackgroundColor -FontColor White
        # HorizontalAlignment "Center" of columns B-K
        $WorkSheet.Cells["B:K"].Style.HorizontalAlignment="Center"
        }
    }
}

# File Size (XLSX)
if (Test-Path "$OUTPUT_FOLDER\XLSX\AuthenticationMethods.xlsx")
{
    $Size = Get-FileSize((Get-Item "$OUTPUT_FOLDER\XLSX\AuthenticationMethods.xlsx").Length)
    Write-Output "[Info]  File Size (XLSX): $Size"
}

#############################################################################################################################################################################################

# Count Users (UPN)
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Measure-Object).Count
$Users = '{0:N0}' -f $Count
Write-Output "[Info]  $Users User(s) found"

# Single-Factor Authentication
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.MFAstatus -eq "Disabled" } | Where-Object { $_.password -eq "True" } | Measure-Object).Count
$SFA = '{0:N0}' -f $Count
Write-Output "[Info]  $SFA User(s) have Single-Factor Authentication enabled ($Users)"

# Multi-Factor Authentication
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.MFAstatus -eq "Enabled" } | Measure-Object).Count
$MFA = '{0:N0}' -f $Count
Write-Output "[Info]  $MFA User(s) have Multi-Factor Authentication enabled ($Users)"

# Password Authentication Method (First-Factor Authentication)
# https://learn.microsoft.com/en-us/graph/api/resources/passwordauthenticationmethod?view=graph-rest-1.0
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.password -eq "True" } | Measure-Object).Count
$Password = '{0:N0}' -f $Count
Write-Output "[Info]  $Password User(s) sign in with a password (First-Factor Authentication)"

# Microsoft Authenticator Authentication Method
# https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethod?view=graph-rest-1.0
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.app -eq "True" } | Measure-Object).Count
$App = '{0:N0}' -f $Count
Write-Output "[Info]  $App User(s) sign in with the Microsoft Authenticator app"

# Phone Authentication Method
# https://learn.microsoft.com/en-us/graph/api/resources/phoneauthenticationmethod?view=graph-rest-1.0
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.phone -eq "True" } | Measure-Object).Count
$Phone = '{0:N0}' -f $Count
Write-Output "[Info]  $Phone User(s) sign in with a phone call or a text message (SMS)"

# Email Authentication Method
# https://learn.microsoft.com/en-us/graph/api/resources/emailauthenticationmethod?view=graph-rest-1.0
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.email -eq "True" } | Measure-Object).Count
$Email = '{0:N0}' -f $Count
Write-Output "[Info]  $Email User(s) sign in with an Email OTP"

# FIDO2 Authentication Method
# https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethod?view=graph-rest-1.0
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.fido2 -eq "True" } | Measure-Object).Count
$FIDO2 = '{0:N0}' -f $Count
Write-Output "[Info]  $FIDO2 User(s) sign in with FIDO2 Security Keys"

# Software OATH Authentication Method (Software Token)
# https://learn.microsoft.com/en-us/graph/api/resources/softwareoathauthenticationmethod?view=graph-rest-1.0
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.softwareoath -eq "True" } | Measure-Object).Count
$SoftwareOath = '{0:N0}' -f $Count
Write-Output "[Info]  $SoftwareOath User(s) sign in with an OATH Time-Based One Time Password (TOTP)"

# Windows Hello For Business Authentication Method (Passwordless)
# https://learn.microsoft.com/en-us/graph/api/resources/windowshelloforbusinessauthenticationmethod?view=graph-rest-1.0
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.hellobusiness -eq "True" } | Measure-Object).Count
$HelloBusiness = '{0:N0}' -f $Count
Write-Output "[Info]  $HelloBusiness User(s) sign in with a Windows Hello for Business Key"

# Temporary Access Pass Authentication Method (Passwordless)
# https://learn.microsoft.com/en-us/graph/api/resources/temporaryaccesspassauthenticationmethod?view=graph-rest-1.0
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.tempaccess -eq "True" } | Measure-Object).Count
$TemporaryAccessPass = '{0:N0}' -f $Count
Write-Output "[Info]  $TemporaryAccessPass User(s) sign in with a Temporary Access Pass (TAP)"

# Certificate-based Authentication Method (Passwordless)
# https://learn.microsoft.com/en-us/graph/api/resources/certificateBasedAuthConfiguration?view=graph-rest-1.0
$Count = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.certificateBasedAuthConfiguration -eq "True" } | Measure-Object).Count
$Certificate = '{0:N0}' -f $Count
Write-Output "[Info]  $Certificate User(s) sign in with a X.509 Certificate (CBA)"

#############################################################################################################################################################################################

# Stats
New-Item "$OUTPUT_FOLDER\Stats\CSV" -ItemType Directory -Force | Out-Null
New-Item "$OUTPUT_FOLDER\Stats\XLSX" -ItemType Directory -Force | Out-Null

# MFA Status (Stats)
$Total = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Select-Object MFAstatus | Measure-Object).Count
Import-Csv -Path "$AuthenticationMethods" -Delimiter "," -Encoding UTF8 | Group-Object MFAstatus | Select-Object @{Name='MFA Status'; Expression={$_.Name}},Count,@{Name='PercentUse'; Expression={"{0:p2}" -f ($_.Count / $Total)}} | Sort-Object Count -Descending | Export-Csv -Path "$OUTPUT_FOLDER\Stats\CSV\MFA-Status.csv" -NoTypeInformation -Encoding UTF8

# XLSX
if (Test-Path "$OUTPUT_FOLDER\Stats\CSV\MFA-Status.csv")
{
    if(!([String]::IsNullOrWhiteSpace((Get-Content "$OUTPUT_FOLDER\Stats\CSV\MFA-Status.csv"))))
    {
        $IMPORT = Import-Csv "$OUTPUT_FOLDER\Stats\CSV\MFA-Status.csv" -Delimiter ","
        $IMPORT | Export-Excel -Path "$OUTPUT_FOLDER\Stats\XLSX\MFA-Status.xlsx" -FreezeTopRow -BoldTopRow -AutoSize -AutoFilter -WorkSheetname "MFA-Status" -CellStyleSB {
        param($WorkSheet)
        # BackgroundColor and FontColor for specific cells of TopRow
        $BackgroundColor = [System.Drawing.Color]::FromArgb(50,60,220)
        Set-Format -Address $WorkSheet.Cells["A1:C1"] -BackgroundColor $BackgroundColor -FontColor White
        # HorizontalAlignment "Center" of columns A-C
        $WorkSheet.Cells["A:C"].Style.HorizontalAlignment="Center"
        }
    }
}

# Authentication Method (Stats)
$Total = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Select-Object UserPrincipalName | Measure-Object).Count
$Password = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.MFAstatus -eq "Disabled" } | Where-Object { $_.password -eq "True" } | Measure-Object).Count
$AuthenticatorApp = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.app -eq "True" } | Measure-Object).Count
$Phone = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.phone -eq "True" } | Measure-Object).Count
$Email = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.email -eq "True" } | Measure-Object).Count
$FIDO2 = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.fido2 -eq "True" } | Measure-Object).Count
$SoftwareOath = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.softwareoath -eq "True" } | Measure-Object).Count
$HelloBusiness = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.hellobusiness -eq "True" } | Measure-Object).Count
$TAP = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.tempaccess -eq "True" } | Measure-Object).Count
$CBA = (Import-Csv -Path "$AuthenticationMethods" -Delimiter "," | Where-Object { $_.certificateBasedAuthConfiguration -eq "True" } | Measure-Object).Count

# CSV
Write-Output "AuthenticationMethod,Count" | Out-File "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv"
Write-Output "Single-Factor Authentication,$Password" | Out-File "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv" -Append # Single-Factor Authentication
Write-Output "Microsoft Authenticator,$AuthenticatorApp" | Out-File "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv" -Append
Write-Output "Phone,$Phone" | Out-File "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv" -Append
Write-Output "E-Mail,$Email" | Out-File "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv" -Append
Write-Output "FIDO2,$FIDO2" | Out-File "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv" -Append
Write-Output "SoftwareOath,$SoftwareOath" | Out-File "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv" -Append
Write-Output "Windows Hello for Business,$HelloBusiness" | Out-File "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv" -Append
Write-Output "Temporary Access Pass,$TAP" | Out-File "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv" -Append
Write-Output "Certificate-Based Authentication,$CBA" | Out-File "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv" -Append

# XLSX
if (Test-Path "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv")
{
    if(!([String]::IsNullOrWhiteSpace((Get-Content "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv"))))
    {
        $IMPORT = Import-Csv "$OUTPUT_FOLDER\Stats\CSV\AuthenticationMethod.csv" -Delimiter "," | Select-Object AuthenticationMethod,Count,@{Name='PercentUse'; Expression={"{0:p2}" -f ($_.Count / $Total)}}
        $IMPORT | Export-Excel -Path "$OUTPUT_FOLDER\Stats\XLSX\AuthenticationMethod.xlsx" -FreezeTopRow -BoldTopRow -AutoSize -AutoFilter -WorkSheetname "Authentication Method" -CellStyleSB {
        param($WorkSheet)
        # BackgroundColor and FontColor for specific cells of TopRow
        $BackgroundColor = [System.Drawing.Color]::FromArgb(50,60,220)
        Set-Format -Address $WorkSheet.Cells["A1:C1"] -BackgroundColor $BackgroundColor -FontColor White
        # HorizontalAlignment "Center" of columns B-C
        $WorkSheet.Cells["B:C"].Style.HorizontalAlignment="Center"
        }
    }
}

#############################################################################################################################################################################################

# Processing User Registration Details
Write-Output "[Info]  Processing User Registration Details ..."

#$File = Get-Item "$AuthenticationMethods"
#$Prefix = $File.Name | ForEach-Object{($_ -split "-")[0]}
#$FilePath = $File.Directory
#$UserRegistrationDetails = "$FilePath".replace('/','\') + "\" + "$Prefix" + "-MFA-UserRegistrationDetails.csv"
$UserRegistrationDetails = "$AuthenticationMethods".replace('AuthenticationMethods','UserRegistrationDetails')
echo "---------------------------------------------------------"
echo $AuthenticationMethods
echo $UserRegistrationDetails
echo "---------------------------------------------------------"
# Input-Check
if (!(Test-Path "$UserRegistrationDetails"))
{
    Write-Host "[Error] $UserRegistrationDetails does not exist." -ForegroundColor Red
    Write-Host ""
    Stop-Transcript
    $Host.UI.RawUI.WindowTitle = "$DefaultWindowsTitle"
    Exit
}

# Input Size
$InputSize = Get-FileSize((Get-Item "$UserRegistrationDetails").Length)
Write-Output "[Info]  Total Input Size: $InputSize"

# Count rows of CSV (w/ thousands separators)
$Count = 0
switch -File "$UserRegistrationDetails" { default { ++$Count } }
$Rows = '{0:N0}' -f $Count
Write-Output "[Info]  Total Lines: $Rows"

# User Registration Details
# https://learn.microsoft.com/en-us/entra/identity/authentication/howto-authentication-methods-activity
# https://learn.microsoft.com/en-us/graph/api/authenticationmethodsroot-list-userregistrationdetails?view=graph-rest-1.0
# https://learn.microsoft.com/en-us/graph/api/resources/userregistrationdetails?view=graph-rest-1.0

# CSV
if (Test-Path "$UserRegistrationDetails")
{
    $Data = Import-Csv -Path "$UserRegistrationDetails" -Delimiter "," -Encoding UTF8

    # Check Timestamp Format
    $Timestamp = ($Data | Select-Object LastUpdatedDateTime -First 1).LastUpdatedDateTime

    # de-DE
    if ($Timestamp -match "\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2}")
    {
        $script:TimestampFormat = "dd.MM.yyyy HH:mm:ss"
    }

    # en-US
    if ($Timestamp -match "\d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2}:\d{2} (AM|PM)")
    {
        $script:TimestampFormat = "M/d/yyyy h:mm:ss tt"
    }

    $Results = [Collections.Generic.List[PSObject]]::new()
    ForEach($Record in $Data)
    {

        $Line = [PSCustomObject]@{
        "Id"                                            = $Record.Id # User object identifier in Microsoft Entra ID.
        "UserDisplayName"                               = $Record.UserDisplayName # User Display Name
        "UserPrincipalName"                             = $Record.UserPrincipalName # User Principal Name
        "IsAdmin"                                       = $Record.IsAdmin # Indicates whether the user has an admin role in the tenant. This value can be used to check the authentication methods that privileged accounts are registered for and capable of.
        "MFA Capable"                                   = $Record.IsMfaCapable # Indicates whether the user has registered a strong authentication method for multifactor authentication. The method must be allowed by the authentication methods policy.
        "MFA Registered"                                = $Record.IsMfaRegistered # Indicates whether the user has registered a strong authentication method for multifactor authentication. 
        "Passwordless Capable"                          = $Record.IsPasswordlessCapable # Indicates whether the user has registered a passwordless strong authentication method (including FIDO2, Windows Hello for Business, and Microsoft Authenticator (Passwordless) that is allowed by the authentication methods policy.
        "SSPR Capable"                                  = $Record.IsSsprCapable # Indicates whether the user has registered the required number of authentication methods for self-service password reset and the user is allowed to perform self-service password reset by policy.
        "SSPR Enabled"                                  = $Record.IsSsprEnabled # Indicates whether the user is allowed to perform self-service password reset by policy. The user may not necessarily have registered the required number of authentication methods for self-service password reset.
        "IsSystemPreferredAuthenticationMethodEnabled"  = $Record.IsSystemPreferredAuthenticationMethodEnabled # Indicates whether system preferred authentication method is enabled. If enabled, the system dynamically determines the most secure authentication method among the methods registered by the user.
        "MethodsRegistered"                             = ($Record | Select-Object -ExpandProperty MethodsRegistered).Replace("`r","").Replace("`n",", ").TrimEnd(", ") # Authentication methods used during registration
        "SystemPreferredAuthenticationMethods"          = $Record.SystemPreferredAuthenticationMethods # Collection of authentication methods that the system determined to be the most secure authentication methods among the registered methods for second factor authentication.
        "UserPreferredMethodForSecondaryAuthentication" = $Recrod.UserPreferredMethodForSecondaryAuthentication # The method the user selected as the default second-factor for performing multi-factor authentication.
        "UserType"                                      = $Record.UserType | ForEach-Object { $_.Replace("member","Member") } | ForEach-Object { $_.Replace("guest","Guest") } # Identifies whether the user is a member or guest in the tenant.
        "LastUpdatedDateTime"                           = ($Record | Select-Object @{Name="LastUpdatedDateTime";Expression={([DateTime]::ParseExact($_.LastUpdatedDateTime, "$TimestampFormat", [cultureinfo]::InvariantCulture).ToString("yyyy-MM-dd HH:mm:ss"))}}).LastUpdatedDateTime # The date and time (UTC) when the record was last updated.
        }

        $Results.Add($Line)
    }

    $Results | Export-Csv -Path "$OUTPUT_FOLDER\CSV\UserRegistrationDetails.csv" -NoTypeInformation
}

# XLSX
if (Test-Path "$UserRegistrationDetails")
{
    if(!([String]::IsNullOrWhiteSpace((Get-Content "$OUTPUT_FOLDER\CSV\UserRegistrationDetails.csv"))))
    {
        $IMPORT = Import-Csv -Path "$OUTPUT_FOLDER\CSV\UserRegistrationDetails.csv" -Delimiter "," -Encoding UTF8
        $IMPORT | Export-Excel -Path "$OUTPUT_FOLDER\XLSX\UserRegistrationDetails.xlsx" -FreezeTopRow -BoldTopRow -AutoSize -AutoFilter -WorkSheetname "User Registration Details" -CellStyleSB {
        param($WorkSheet)
        # BackgroundColor and FontColor for specific cells of TopRow
        $BackgroundColor = [System.Drawing.Color]::FromArgb(50,60,220)
        Set-Format -Address $WorkSheet.Cells["A1:O1"] -BackgroundColor $BackgroundColor -FontColor White
        # HorizontalAlignment "Center" of columns B-O
        $WorkSheet.Cells["B:O"].Style.HorizontalAlignment="Center"
        }
    }
}

# File Size (XLSX)
if (Test-Path "$OUTPUT_FOLDER\XLSX\UserRegistrationDetails.xlsx")
{
    $Size = Get-FileSize((Get-Item "$OUTPUT_FOLDER\XLSX\UserRegistrationDetails.xlsx").Length)
    Write-Output "[Info]  File Size (XLSX): $Size"
}

#############################################################################################################################################################################################

# Users capable of Azure Multi-Factor Authentication
$Total = (Import-Csv -Path "$UserRegistrationDetails" -Delimiter "," | Select-Object Id | Measure-Object).Count
$Count = (Import-Csv -Path "$UserRegistrationDetails" -Delimiter "," | Where-Object { $_.IsMfaCapable -eq "True" } | Measure-Object).Count
$MFACapable = '{0:N0}' -f $Count
Write-Output "[Info]  $MFACapable Users capable of Azure Multi-Factor Authentication ($Total)"

# Users capable of Passwordless Authentication
$Total = (Import-Csv -Path "$UserRegistrationDetails" -Delimiter "," | Select-Object Id | Measure-Object).Count
$Count = (Import-Csv -Path "$UserRegistrationDetails" -Delimiter "," | Where-Object { $_.IsPasswordlessCapable -eq "True" } | Measure-Object).Count
$PasswordlessCapable = '{0:N0}' -f $Count
Write-Output "[Info]  $PasswordlessCapable Users capable of Passwordless Authentication ($Total)"

# Users capable of Self-Service Password Reset (SSPR)
$Total = (Import-Csv -Path "$UserRegistrationDetails" -Delimiter "," | Select-Object Id | Measure-Object).Count
$Count = (Import-Csv -Path "$UserRegistrationDetails" -Delimiter "," | Where-Object { $_.IsSsprCapable -eq "True" } | Measure-Object).Count
$SSPRCapable = '{0:N0}' -f $Count
Write-Output "[Info]  $SSPRCapable Users capable of Self-Service Password Reset ($Total)"

# Second-Factor Authentication Method
$Check = (Import-Csv "$UserRegistrationDetails" -Delimiter "," | Where-Object {$_.MethodsRegistered -ne '' } | Select-Object MethodsRegistered | Measure-Object).Count
if ("$Check" -eq 0)
{
    Write-Host "[Alert] 0 Users registered a Second-Factor Authentication Method ($Total)" -ForegroundColor Red
}

# MethodsRegistered (Stats)
$Check = (Import-Csv "$UserRegistrationDetails" -Delimiter "," | Where-Object {$_.MethodsRegistered -ne '' } | Select-Object MethodsRegistered | Measure-Object).Count
if ("$Check" -ge 1)
{
    $Total = ((Import-Csv "$UserRegistrationDetails" -Delimiter "," | Where-Object {$_.MethodsRegistered -ne '' } | Select-Object -ExpandProperty MethodsRegistered).Replace("`r","").Trim() | Measure-Object).Count
    (Import-Csv "$UserRegistrationDetails" -Delimiter "," | Where-Object {$_.MethodsRegistered -ne '' } | Select-Object -ExpandProperty MethodsRegistered).Replace("`r","").Trim() | Out-File "$OUTPUT_FOLDER\Stats\MethodsRegistered.txt" -Encoding UTF8
    Get-Content "$OUTPUT_FOLDER\Stats\MethodsRegistered.txt" -Encoding UTF8 | Group-Object | Select-Object @{Name='MethodsRegistered'; Expression={$_.Name}},Count,@{Name='PercentUse'; Expression={"{0:p2}" -f ($_.Count / $Total)}} | Sort-Object Count -Descending | Export-Csv -Path "$OUTPUT_FOLDER\Stats\CSV\MethodsRegistered.csv" -NoTypeInformation -Encoding UTF8
}

# Cleaning up
if (Test-Path "$OUTPUT_FOLDER\Stats\MethodsRegistered.txt")
{
    Remove-Item "$OUTPUT_FOLDER\Stats\MethodsRegistered.txt" -Force
}

# XLSX
if (Test-Path "$OUTPUT_FOLDER\Stats\CSV\MethodsRegistered.csv")
{
    if(!([String]::IsNullOrWhiteSpace((Get-Content "$OUTPUT_FOLDER\Stats\CSV\MethodsRegistered.csv"))))
    {
        $IMPORT = Import-Csv "$OUTPUT_FOLDER\Stats\CSV\MethodsRegistered.csv" -Delimiter ","
        $IMPORT | Export-Excel -Path "$OUTPUT_FOLDER\Stats\XLSX\MethodsRegistered.xlsx" -FreezeTopRow -BoldTopRow -AutoSize -AutoFilter -WorkSheetname "Methods Registered" -CellStyleSB {
        param($WorkSheet)
        # BackgroundColor and FontColor for specific cells of TopRow
        $BackgroundColor = [System.Drawing.Color]::FromArgb(50,60,220)
        Set-Format -Address $WorkSheet.Cells["A1:C1"] -BackgroundColor $BackgroundColor -FontColor White
        # HorizontalAlignment "Center" of columns B-C
        $WorkSheet.Cells["B:C"].Style.HorizontalAlignment="Center"
        }
    }
}

#endregion Analysis

#############################################################################################################################################################################################
#############################################################################################################################################################################################

#region Footer

# Get End Time
$endTime = (Get-Date)

# Echo Time elapsed
Write-Output ""
Write-Output "FINISHED!"

$Time = ($endTime-$startTime)
$ElapsedTime = ('Overall analysis duration: {0} h {1} min {2} sec' -f $Time.Hours, $Time.Minutes, $Time.Seconds)
Write-Output "$ElapsedTime"

# Stop logging
Write-Host ""
Stop-Transcript
Start-Sleep 1

# Reset Windows Title
$Host.UI.RawUI.WindowTitle = "$DefaultWindowsTitle"

#endregion Footer

#############################################################################################################################################################################################
#############################################################################################################################################################################################

# SIG # Begin signature block
# MIIrxQYJKoZIhvcNAQcCoIIrtjCCK7ICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUEEhYzYwVP5nK1th4oBptfCyr
# XI6ggiT/MIIFbzCCBFegAwIBAgIQSPyTtGBVlI02p8mKidaUFjANBgkqhkiG9w0B
# AQwFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEh
# MB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTIxMDUyNTAwMDAw
# MFoXDTI4MTIzMTIzNTk1OVowVjELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3Rp
# Z28gTGltaXRlZDEtMCsGA1UEAxMkU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5n
# IFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjeeUEiIE
# JHQu/xYjApKKtq42haxH1CORKz7cfeIxoFFvrISR41KKteKW3tCHYySJiv/vEpM7
# fbu2ir29BX8nm2tl06UMabG8STma8W1uquSggyfamg0rUOlLW7O4ZDakfko9qXGr
# YbNzszwLDO/bM1flvjQ345cbXf0fEj2CA3bm+z9m0pQxafptszSswXp43JJQ8mTH
# qi0Eq8Nq6uAvp6fcbtfo/9ohq0C/ue4NnsbZnpnvxt4fqQx2sycgoda6/YDnAdLv
# 64IplXCN/7sVz/7RDzaiLk8ykHRGa0c1E3cFM09jLrgt4b9lpwRrGNhx+swI8m2J
# mRCxrds+LOSqGLDGBwF1Z95t6WNjHjZ/aYm+qkU+blpfj6Fby50whjDoA7NAxg0P
# OM1nqFOI+rgwZfpvx+cdsYN0aT6sxGg7seZnM5q2COCABUhA7vaCZEao9XOwBpXy
# bGWfv1VbHJxXGsd4RnxwqpQbghesh+m2yQ6BHEDWFhcp/FycGCvqRfXvvdVnTyhe
# Be6QTHrnxvTQ/PrNPjJGEyA2igTqt6oHRpwNkzoJZplYXCmjuQymMDg80EY2NXyc
# uu7D1fkKdvp+BRtAypI16dV60bV/AK6pkKrFfwGcELEW/MxuGNxvYv6mUKe4e7id
# FT/+IAx1yCJaE5UZkADpGtXChvHjjuxf9OUCAwEAAaOCARIwggEOMB8GA1UdIwQY
# MBaAFKARCiM+lvEH7OKvKe+CpX/QMKS0MB0GA1UdDgQWBBQy65Ka/zWWSC8oQEJw
# IDaRXBeF5jAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUE
# DDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEMGA1Ud
# HwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0FBQUNlcnRpZmlj
# YXRlU2VydmljZXMuY3JsMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuY29tb2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4IBAQASv6Hvi3Sa
# mES4aUa1qyQKDKSKZ7g6gb9Fin1SB6iNH04hhTmja14tIIa/ELiueTtTzbT72ES+
# BtlcY2fUQBaHRIZyKtYyFfUSg8L54V0RQGf2QidyxSPiAjgaTCDi2wH3zUZPJqJ8
# ZsBRNraJAlTH/Fj7bADu/pimLpWhDFMpH2/YGaZPnvesCepdgsaLr4CnvYFIUoQx
# 2jLsFeSmTD1sOXPUC4U5IOCFGmjhp0g4qdE2JXfBjRkWxYhMZn0vY86Y6GnfrDyo
# XZ3JHFuu2PMvdM+4fvbXg50RlmKarkUT2n/cR/vfw1Kf5gZV6Z2M8jpiUbzsJA8p
# 1FiAhORFe1rYMIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c9MfjPzANBgkqhkiG
# 9w0BAQwFADBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2
# MB4XDTIxMDMyMjAwMDAwMFoXDTM2MDMyMTIzNTk1OVowVTELMAkGA1UEBhMCR0Ix
# GDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJs
# aWMgVGltZSBTdGFtcGluZyBDQSBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAw
# ggGKAoIBgQDNmNhDQatugivs9jN+JjTkiYzT7yISgFQ+7yavjA6Bg+OiIjPm/N/t
# 3nC7wYUrUlY3mFyI32t2o6Ft3EtxJXCc5MmZQZ8AxCbh5c6WzeJDB9qkQVa46xiY
# Epc81KnBkAWgsaXnLURoYZzksHIzzCNxtIXnb9njZholGw9djnjkTdAA83abEOHQ
# 4ujOGIaBhPXG2NdV8TNgFWZ9BojlAvflxNMCOwkCnzlH4oCw5+4v1nssWeN1y4+R
# laOywwRMUi54fr2vFsU5QPrgb6tSjvEUh1EC4M29YGy/SIYM8ZpHadmVjbi3Pl8h
# JiTWw9jiCKv31pcAaeijS9fc6R7DgyyLIGflmdQMwrNRxCulVq8ZpysiSYNi79tw
# 5RHWZUEhnRfs/hsp/fwkXsynu1jcsUX+HuG8FLa2BNheUPtOcgw+vHJcJ8HnJCrc
# UWhdFczf8O+pDiyGhVYX+bDDP3GhGS7TmKmGnbZ9N+MpEhWmbiAVPbgkqykSkzyY
# Vr15OApZYK8CAwEAAaOCAVwwggFYMB8GA1UdIwQYMBaAFPZ3at0//QET/xahbIIC
# L9AKPRQlMB0GA1UdDgQWBBRfWO1MMXqiYUKNUoC6s2GXGaIymzAOBgNVHQ8BAf8E
# BAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDCDAR
# BgNVHSAECjAIMAYGBFUdIAAwTAYDVR0fBEUwQzBBoD+gPYY7aHR0cDovL2NybC5z
# ZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5nUm9vdFI0Ni5jcmww
# fAYIKwYBBQUHAQEEcDBuMEcGCCsGAQUFBzAChjtodHRwOi8vY3J0LnNlY3RpZ28u
# Y29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdSb290UjQ2LnA3YzAjBggrBgEF
# BQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQADggIB
# ABLXeyCtDjVYDJ6BHSVY/UwtZ3Svx2ImIfZVVGnGoUaGdltoX4hDskBMZx5NY5L6
# SCcwDMZhHOmbyMhyOVJDwm1yrKYqGDHWzpwVkFJ+996jKKAXyIIaUf5JVKjccev3
# w16mNIUlNTkpJEor7edVJZiRJVCAmWAaHcw9zP0hY3gj+fWp8MbOocI9Zn78xvm9
# XKGBp6rEs9sEiq/pwzvg2/KjXE2yWUQIkms6+yslCRqNXPjEnBnxuUB1fm6bPAV+
# Tsr/Qrd+mOCJemo06ldon4pJFbQd0TQVIMLv5koklInHvyaf6vATJP4DfPtKzSBP
# kKlOtyaFTAjD2Nu+di5hErEVVaMqSVbfPzd6kNXOhYm23EWm6N2s2ZHCHVhlUgHa
# C4ACMRCgXjYfQEDtYEK54dUwPJXV7icz0rgCzs9VI29DwsjVZFpO4ZIVR33LwXyP
# DbYFkLqYmgHjR3tKVkhh9qKV2WCmBuC27pIOx6TYvyqiYbntinmpOqh/QPAnhDge
# xKG9GX/n1PggkGi9HCapZp8fRwg8RftwS21Ln61euBG0yONM6noD2XQPrFwpm3Gc
# uqJMf0o8LLrFkSLRQNwxPDDkWXhW+gZswbaiie5fd/W2ygcto78XCSPfFWveUOSZ
# 5SqK95tBO8aTHmEa4lpJVD7HrTEn9jb1EGvxOb1cnn0CMIIGGjCCBAKgAwIBAgIQ
# Yh1tDFIBnjuQeRUgiSEcCjANBgkqhkiG9w0BAQwFADBWMQswCQYDVQQGEwJHQjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdvIFB1Ymxp
# YyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwHhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIx
# MjM1OTU5WjBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MIIB
# ojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAmyudU/o1P45gBkNqwM/1f/bI
# U1MYyM7TbH78WAeVF3llMwsRHgBGRmxDeEDIArCS2VCoVk4Y/8j6stIkmYV5Gej4
# NgNjVQ4BYoDjGMwdjioXan1hlaGFt4Wk9vT0k2oWJMJjL9G//N523hAm4jF4UjrW
# 2pvv9+hdPX8tbbAfI3v0VdJiJPFy/7XwiunD7mBxNtecM6ytIdUlh08T2z7mJEXZ
# D9OWcJkZk5wDuf2q52PN43jc4T9OkoXZ0arWZVeffvMr/iiIROSCzKoDmWABDRzV
# /UiQ5vqsaeFaqQdzFf4ed8peNWh1OaZXnYvZQgWx/SXiJDRSAolRzZEZquE6cbcH
# 747FHncs/Kzcn0Ccv2jrOW+LPmnOyB+tAfiWu01TPhCr9VrkxsHC5qFNxaThTG5j
# 4/Kc+ODD2dX/fmBECELcvzUHf9shoFvrn35XGf2RPaNTO2uSZ6n9otv7jElspkfK
# 9qEATHZcodp+R4q2OIypxR//YEb3fkDn3UayWW9bAgMBAAGjggFkMIIBYDAfBgNV
# HSMEGDAWgBQy65Ka/zWWSC8oQEJwIDaRXBeF5jAdBgNVHQ4EFgQUDyrLIIcouOxv
# SK4rVKYpqhekzQwwDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAw
# EwYDVR0lBAwwCgYIKwYBBQUHAwMwGwYDVR0gBBQwEjAGBgRVHSAAMAgGBmeBDAEE
# ATBLBgNVHR8ERDBCMECgPqA8hjpodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3Rp
# Z29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RSNDYuY3JsMHsGCCsGAQUFBwEBBG8wbTBG
# BggrBgEFBQcwAoY6aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGlj
# Q29kZVNpZ25pbmdSb290UjQ2LnA3YzAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Au
# c2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQADggIBAAb/guF3YzZue6EVIJsT/wT+
# mHVEYcNWlXHRkT+FoetAQLHI1uBy/YXKZDk8+Y1LoNqHrp22AKMGxQtgCivnDHFy
# AQ9GXTmlk7MjcgQbDCx6mn7yIawsppWkvfPkKaAQsiqaT9DnMWBHVNIabGqgQSGT
# rQWo43MOfsPynhbz2Hyxf5XWKZpRvr3dMapandPfYgoZ8iDL2OR3sYztgJrbG6VZ
# 9DoTXFm1g0Rf97Aaen1l4c+w3DC+IkwFkvjFV3jS49ZSc4lShKK6BrPTJYs4NG1D
# GzmpToTnwoqZ8fAmi2XlZnuchC4NPSZaPATHvNIzt+z1PHo35D/f7j2pO1S8BCys
# QDHCbM5Mnomnq5aYcKCsdbh0czchOm8bkinLrYrKpii+Tk7pwL7TjRKLXkomm5D1
# Umds++pip8wH2cQpf93at3VDcOK4N7EwoIJB0kak6pSzEu4I64U6gZs7tS/dGNSl
# jf2OSSnRr7KWzq03zl8l75jy+hOds9TWSenLbjBQUGR96cFr6lEUfAIEHVC1L68Y
# 1GGxx4/eRI82ut83axHMViw1+sVpbPxg51Tbnio1lB93079WPFnYaOvfGAA0e0zc
# fF/M9gXr+korwQTh2Prqooq2bYNMvUoUKD85gnJ+t0smrWrb8dee2CvYZXD5laGt
# aAxOfy/VKNmwuWuAh9kcMIIGXTCCBMWgAwIBAgIQOlJqLITOVeYdZfzMEtjpiTAN
# BgkqhkiG9w0BAQwFADBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBM
# aW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENB
# IFIzNjAeFw0yNDAxMTUwMDAwMDBaFw0zNTA0MTQyMzU5NTlaMG4xCzAJBgNVBAYT
# AkdCMRMwEQYDVQQIEwpNYW5jaGVzdGVyMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0
# ZWQxMDAuBgNVBAMTJ1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVy
# IFIzNTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAI3RZ/TBSJu9/ThJ
# Ok1hgZvD2NxFpWEENo0GnuOYloD11BlbmKCGtcY0xiMrsN7LlEgcyoshtP3P2J/v
# neZhuiMmspY7hk/Q3l0FPZPBllo9vwT6GpoNnxXLZz7HU2ITBsTNOs9fhbdAWr/M
# m8MNtYov32osvjYYlDNfefnBajrQqSV8Wf5ZvbaY5lZhKqQJUaXxpi4TXZKohLgx
# U7g9RrFd477j7jxilCU2ptz+d1OCzNFAsXgyPEM+NEMPUz2q+ktNlxMZXPF9WLIh
# OhE3E8/oNSJkNTqhcBGsbDI/1qCU9fBhuSojZ0u5/1+IjMG6AINyI6XLxM8OAGQm
# aMB8gs2IZxUTOD7jTFR2HE1xoL7qvSO4+JHtvNceHu//dGeVm5Pdkay3Et+YTt9E
# wAXBsd0PPmC0cuqNJNcOI0XnwjE+2+Zk8bauVz5ir7YHz7mlj5Bmf7W8SJ8jQwO2
# IDoHHFC46ePg+eoNors0QrC0PWnOgDeMkW6gmLBtq3CEOSDU8iNicwNsNb7ABz0W
# 1E3qlSw7jTmNoGCKCgVkLD2FaMs2qAVVOjuUxvmtWMn1pIFVUvZ1yrPIVbYt1aTl
# d2nrmh544Auh3tgggy/WluoLXlHtAJgvFwrVsKXj8ekFt0TmaPL0lHvQEe5jHbuf
# hc05lvCtdwbfBl/2ARSTuy1s8CgFAgMBAAGjggGOMIIBijAfBgNVHSMEGDAWgBRf
# WO1MMXqiYUKNUoC6s2GXGaIymzAdBgNVHQ4EFgQUaO+kMklptlI4HepDOSz0FGqe
# DIUwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYI
# KwYBBQUHAwgwSgYDVR0gBEMwQTA1BgwrBgEEAbIxAQIBAwgwJTAjBggrBgEFBQcC
# ARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQCMEoGA1UdHwRDMEEw
# P6A9oDuGOWh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVT
# dGFtcGluZ0NBUjM2LmNybDB6BggrBgEFBQcBAQRuMGwwRQYIKwYBBQUHMAKGOWh0
# dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ0NB
# UjM2LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJ
# KoZIhvcNAQEMBQADggGBALDcLsn6TzZMii/2yU/V7xhPH58Oxr/+EnrZjpIyvYTz
# 2u/zbL+fzB7lbrPml8ERajOVbudan6x08J1RMXD9hByq+yEfpv1G+z2pmnln5Xuc
# fA9MfzLMrCArNNMbUjVcRcsAr18eeZeloN5V4jwrovDeLOdZl0tB7fOX5F6N2rmX
# aNTuJR8yS2F+EWaL5VVg+RH8FelXtRvVDLJZ5uqSNIckdGa/eUFhtDKTTz9LtOUh
# 46v2JD5Q3nt8mDhAjTKp2fo/KJ6FLWdKAvApGzjpPwDqFeJKf+kJdoBKd2zQuwzk
# 5Wgph9uA46VYK8p/BTJJahKCuGdyKFIFfEfakC4NXa+vwY4IRp49lzQPLo7Wticq
# Maaqb8hE2QmCFIyLOvWIg4837bd+60FcCGbHwmL/g1ObIf0rRS9ceK4DY9rfBnHF
# H2v1d4hRVvZXyCVlrL7ZQuVzjjkLMK9VJlXTVkHpuC8K5S4HHTv2AJx6mOdkMJwS
# 4gLlJ7gXrIVpnxG+aIniGDCCBmswggTToAMCAQICEQCMQZ6TvyvOrIgGKDt2Gb08
# MA0GCSqGSIb3DQEBDAUAMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdv
# IExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBD
# QSBSMzYwHhcNMjQxMTE0MDAwMDAwWhcNMjcxMTE0MjM1OTU5WjBXMQswCQYDVQQG
# EwJERTEWMBQGA1UECAwNTmllZGVyc2FjaHNlbjEXMBUGA1UECgwOTWFydGluIFdp
# bGxpbmcxFzAVBgNVBAMMDk1hcnRpbiBXaWxsaW5nMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEA0Z9u5pyMwenbCRSzHsUEDUXfGjL+9w05WuvBukPLvldk
# 2NSUP2eI9qAiPQE1tytz+zQD3ZRNEJrXYwtBf++I7H4pf4vC8Mbsk9N+MGm1YmSl
# HKHZirBBYTPWpvFuZFIC7guRSCuMDTquU382HR08ibtXkdl7kg6DKdMIOOZjrhTQ
# W2AfA1QbR8aG71quHgrN5VMV9O8Ed0K9lLW/dsPHlNryq9krPcSIf2LzOFMYAaTt
# SOjvltrQAeZpspyIKAn1+5ruog9wPgIaUPRr9tPRvN8vBT6xSSFlO+003oRK2z42
# dO+MV8K5RJIZxlApNcPiojbWR2kp9F/r54aie6LQcUGUABEpYVl6Qygrp551Z1YM
# L1VrXHAIcWTveXon+lbLP1IQmgWdurM5Z3hrRXkwpSOPpN5qn1rqHbV4x3PKIQHJ
# Vqe11csJYsIQhRLAHBZKZAsor3stLKhH68IjJ0ctXpR9Ut+13EGmr+fm7eCsbSF7
# jlRMd7zPTB3Za2ltMtaJ+RPIuLWoHSOOUx9C1NPNLm3NjCqqumV7aZU7tcHRdgoM
# t4X0ki5CbHEVgKb6bzjulbXOI0xvwDuoqjeTOksHfoONF7bMQQ/4EpPZDKpICdaQ
# 9RqeYJB5z9b3rrfmICfcVnEQySO73IrParF8LVcm3jgoeeq00Lwv03+gSbYonhEC
# AwEAAaOCAbMwggGvMB8GA1UdIwQYMBaAFA8qyyCHKLjsb0iuK1SmKaoXpM0MMB0G
# A1UdDgQWBBSMcmQJhB5e7gHxMGweJ8yPDAgi2zAOBgNVHQ8BAf8EBAMCB4AwDAYD
# VR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzBKBgNVHSAEQzBBMDUGDCsG
# AQQBsjEBAgEDAjAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQ
# UzAIBgZngQwBBAEwSQYDVR0fBEIwQDA+oDygOoY4aHR0cDovL2NybC5zZWN0aWdv
# LmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcmwweQYIKwYBBQUH
# AQEEbTBrMEQGCCsGAQUFBzAChjhodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3Rp
# Z29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2LmNydDAjBggrBgEFBQcwAYYXaHR0cDov
# L29jc3Auc2VjdGlnby5jb20wKAYDVR0RBCEwH4EdbXdpbGxpbmdAbGV0aGFsLWZv
# cmVuc2ljcy5jb20wDQYJKoZIhvcNAQEMBQADggGBAGdHQTDMJblhm/jA9axlmj7W
# l6zWZ5WajmcYG3azCwSgEK9EBnCCwlSGeEmWGnr0+cjEeoxRkgI4GhbZ5PGaW7Rs
# IoP3nfwvw9TXvEmcn33bQC57P+Qh8TJ1PJLO7re3bEesxQ+P25pY7qFKIueVuv11
# P9aa/rakWmRib40iiUAjfTIRQL10qTz6kbI9u83tfimCARdfy9AVtB0tHfWYRklK
# BMKjAy6UH9nqiRcsss1rdtVVYSxepoGdXRObQi2WOxEc8ev4eTexdMN+taIoIszG
# wjHUk9vVznOZgfKugsnuzphHzNowckVmvnHeEcnLDdqdsB0bpKauPIl/rT1Sph8D
# Sn/rqbijw0AHleCe4FArXryLDraMogtvmpoprvNaONuA5fjbAMgi89El7zQIVb7V
# O9x+tYLaD2v0lqLnptkvm86e6Brxj6Kf/ZoeAl5Iui1Xgx94QzPIWbCYPxE6CFog
# 6M03NslqsFeDs8neMeSMfJXJFzIFrslnMZiytUZiqTCCBoIwggRqoAMCAQICEDbC
# sL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UE
# ChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNB
# IENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTIxMDMyMjAwMDAwMFoXDTM4MDEx
# ODIzNTk1OVowVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRl
# ZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0
# NjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAIid2LlFZ50d3ei5JoGa
# VFTAfEkFm8xaFQ/ZlBBEtEFAgXcUmanU5HYsyAhTXiDQkiUvpVdYqZ1uYoZEMgtH
# ES1l1Cc6HaqZzEbOOp6YiTx63ywTon434aXVydmhx7Dx4IBrAou7hNGsKioIBPy5
# GMN7KmgYmuu4f92sKKjbxqohUSfjk1mJlAjthgF7Hjx4vvyVDQGsd5KarLW5d73E
# 3ThobSkob2SL48LpUR/O627pDchxll+bTSv1gASn/hp6IuHJorEu6EopoB1CNFp/
# +HpTXeNARXUmdRMKbnXWflq+/g36NJXB35ZvxQw6zid61qmrlD/IbKJA6COw/8lF
# SPQwBP1ityZdwuCysCKZ9ZjczMqbUcLFyq6KdOpuzVDR3ZUwxDKL1wCAxgL2Mpz7
# eZbrb/JWXiOcNzDpQsmwGQ6Stw8tTCqPumhLRPb7YkzM8/6NnWH3T9ClmcGSF22L
# EyJYNWCHrQqYubNeKolzqUbCqhSqmr/UdUeb49zYHr7ALL8bAJyPDmubNqMtuaob
# KASBqP84uhqcRY/pjnYd+V5/dcu9ieERjiRKKsxCG1t6tG9oj7liwPddXEcYGOUi
# WLm742st50jGwTzxbMpepmOP1mLnJskvZaN5e45NuzAHteORlsSuDt5t4BBRCJL+
# 5EZnnw0ezntk9R8QJyAkL6/bAgMBAAGjggEWMIIBEjAfBgNVHSMEGDAWgBRTeb9a
# qitKz1SA4dibwJ3ysgNmyzAdBgNVHQ4EFgQU9ndq3T/9ARP/FqFsggIv0Ao9FCUw
# DgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wEwYDVR0lBAwwCgYIKwYB
# BQUHAwgwEQYDVR0gBAowCDAGBgRVHSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6
# Ly9jcmwudXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0
# aG9yaXR5LmNybDA1BggrBgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9v
# Y3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEMBQADggIBAA6+ZUHtaES45aHF
# 1BGH5Lc7JYzrftrIF5Ht2PFDxKKFOct/awAEWgHQMVHol9ZLSyd/pYMbaC0IZ+XB
# W9xhdkkmUV/KbUOiL7g98M/yzRyqUOZ1/IY7Ay0YbMniIibJrPcgFp73WDnRDKtV
# utShPSZQZAdtFwXnuiWl8eFARK3PmLqEm9UsVX+55DbVIz33Mbhba0HUTEYv3yJ1
# fwKGxPBsP/MgTECimh7eXomvMm0/GPxX2uhwCcs/YLxDnBdVVlxvDjHjO1cuwbOp
# kiJGHmLXXVNbsdXUC2xBrq9fLrfe8IBsA4hopwsCj8hTuwKXJlSTrZcPRVSccP5i
# 9U28gZ7OMzoJGlxZ5384OKm0r568Mo9TYrqzKeKZgFo0fj2/0iHbj55hc20jfxvK
# 3mQi+H7xpbzxZOFGm/yVQkpo+ffv5gdhp+hv1GDsvJOtJinJmgGbBFZIThbqI+MH
# vAmMmkfb3fTxmSkop2mSJL1Y2x/955S29Gu0gSJIkc3z30vU/iXrMpWx2tS7UVfV
# P+5tKuzGtgkP7d/doqDrLF1u6Ci3TpjAZdeLLlRQZm867eVeXED58LXd1Dk6UvaA
# hvmWYXoiLz4JA5gPBcz7J311uahxCweNxE+xxxR3kT0WKzASo5G/PyDez6NHdIUK
# BeE3jDPs2ACc6CkJ1Sji4PKWVT0/MYIGMDCCBiwCAQEwaTBUMQswCQYDVQQGEwJH
# QjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1
# YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2AhEAjEGek78rzqyIBig7dhm9PDAJBgUr
# DgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMx
# DAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkq
# hkiG9w0BCQQxFgQUKjj6MC+6UfDT1pcnOGRtRm4NNzowDQYJKoZIhvcNAQEBBQAE
# ggIAtxfPUcWixhCgPfVZdHDuvPehFQTYh6ODkvdMXInaktjZ2WQ13pPnfAI3R0xl
# D6KRNLRUbVudRUeQCwtbq1CeTP2Ic6QgskNmBukgJuID9yzDSJp+W+KXzJf+cMze
# x+yxdUPvEJcTWVZeA0GqM3UIhOyXiBa6+gCIK2YBa/Usw47iBiAFcKf286Ijy3CB
# mOI+PylXo2dhXjdac9bQkDmpxNUwKMn8Off4QzvJndyqBNYokCjaoOtIuzdnUWIO
# CBWx0bahyTpzxj089Q+PRfd26Eh0MnM68hS2/Vxkv2pMfr45pOV494g698V4tE8O
# 001Ao74U075mAPq/c27KzorruTXxbpxiAvalpcuAgZW2WuwYJW5IPFrCpjaPYvx+
# b2XiPLh/UQX8Lc5E0gsfUBLk2nUBWw7hM1pd9RlMhOJzvXCj9Rlu5u6qlqhetDAs
# R76EflK8UPoAxVUbCaICEcGP+eWlZJTvGJB2iL/e7G9BEy4foxyCBV/B9x1oGtwH
# m1O87peVbF50tiiPMceVlpZ3IsNvirB1haEuLn9Q1bqZTOYEVy/hoQveSIgim1ub
# lg108cSzmhgHN4FtGYRgPvKA0pIh0GYm0J8LYom/1bWcyPBTLQ3hIEe5OwoAUJTN
# XF7XGwx6k7NBaB2aIcbg7X6FsH4cfq5ZkA6LGhkbHI3P1AqhggMiMIIDHgYJKoZI
# hvcNAQkGMYIDDzCCAwsCAQEwaTBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2Vj
# dGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1w
# aW5nIENBIFIzNgIQOlJqLITOVeYdZfzMEtjpiTANBglghkgBZQMEAgIFAKB5MBgG
# CSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MDIyNDA2
# MDA1MlowPwYJKoZIhvcNAQkEMTIEMNoSj+gWVNAcxnuP4YtY3a0EL41ZX1r1QROg
# DWzgeKJJ1fk9wA6lbQRIxFziXRycVjANBgkqhkiG9w0BAQEFAASCAgBY8/YqLXx7
# mhW/uRKwfPqmt8PwLpyXEL02++ATIlvi2zOVoMqZBFAmaB3xUP4Dc/YlN2JIX1RK
# lNapvqPLIodp0f2l/tkhcBBVqV1Is37VqVrGj46rffnSV31mSPUy/JRe5pwnR3F6
# EMV1FU0q9/QEIgjmz98p0ANFDqRH/PFlKFDB0RaAiAFv44Zot0S0wQV+4HaCGK8B
# GAanCqL+QD1lvKHLuSiBe7kuugpL0pH6V3WteoRzr1LQmkFaUmk6jBhcvYsOuOYM
# 3q0DdkA24LSbRpV7ZBNz45rLofh2j5TVy8FFXKnAI6/1r5cRGXNbNi6BtXJw1XjU
# P4a9inKX8/w3uraaePX7bYJaWUcm835ACLRMeQBM/xHEq3uaXOBm2nhtrRXPqIRR
# HuP1UVukvNwJnfHP2KDYfjp7Y6OckjMovbcrIhwM+0vbigZvYxarmj9mfmtyM2sG
# 9Ft5h/Zr0pcGK6DUGg0Orur39lE0HHrkMMBN1CATEl89r83kGwxfio1IW+DTjvxs
# gFfXmMqqCszoMNQSKf6rY/R1doHbqtw5+HYrhGVJcT3Kw3H+zRr1RMC7/FoVHpuP
# jQNvnIik0nEztU5mv5Lx4nqBDE9hAoXZTqq8/u74ayNXUb19ajB41s5/lRSRqb7B
# t1VZgYRxDx0yGu+lekMDB6QWEw6PUypqmQ==
# SIG # End signature block
