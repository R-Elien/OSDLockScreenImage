<#
.SYNOPSIS
    Use to set a custom lock screen at the end of the OSD Task Sequence
.DESCRIPTION
    This script can be used to modify the lockscreen of a Windows 10 computer
    Upcoming :
        - Add support of Backup and Restore steps
        - Add parameter to remove Lockscreen on user logon
.PARAMETER Type Specifies the type of image to set
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    Version           :   1.0
    Author            :   Rémi Elien - retool.fr
    Creation Date     :   16/03/2020
    Purpose/Change    :   Initial script development
.EXAMPLE
    Set the Locksreen image to installation successful
    .\OSDLockScreenImage.ps1 -Type "INSTALL_OK"
#>


Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('INSTALL_OK', 'RESET')]
    [string]$Type
)

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$ScriptPath = (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Destfile = "C:\Windows\Temp\$ScriptName\$ScriptName.png"
$LogFileName = "$ScriptName.log"

$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Get-TSVariable($VariableName) {
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    $VariableValue = $tsenv.Value($VariableName)
    Remove-Variable tsenv
    return $VariableValue
}

Function Exit-Error {
    Write-Log -LogFile $LogFile -Message "Script ended on error"
    Write-Log -LogFile $LogFile -Message "-----------------------------------------------------------------------------------------"
    exit 9999
}

Function Write-Log {
    Param (
        [Parameter(Mandatory = $true)]
        [string]$LogFile,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("SUCCESS", "INFO", "WARNING", "ERROR", "DEBUG")]
        [string]$Type = "INFO"
    )

    $DateObject = [System.DateTime]::Now.ToString("dd-MM-yyyy HH:mm:ss")

    $logline = "[$DateObject];[$($Type.ToUpper())];$Message"

    Try {
        $logline | Add-Content -Path $LogFile -Force -Encoding UTF8 -ErrorAction stop
    }
    Catch {
        Write-Host "Fail to write '$logline' in logfile '$LogFile' - Error detail : $_" -ForegroundColor "Red"
    }

}


#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Get the log file path
Try {
    # If the TS variable exist, the directory is used to write the log file
    $LogFileDirectory = Get-TSVariable -VariableName "_SMSTSLogPath"
}
Catch {
    # If no TS variable, writing the log file to Windir\Temp
    $LogFileDirectory = "C:\Windows\Temp\$ScriptName"
}

$LogFile = "$LogFileDirectory\$LogFileName"


# Create log file directory if it does not exist
if (-not(Test-Path -Path $LogFileDirectory -PathType "Container" )) {
    Try {
        New-Item -Path $LogFileDirectory -ItemType "Directory" -ErrorAction "Stop" | Out-Null
    }
    Catch {
        Write-Host "Fail to create log file directory - Error detail : $_" -ForegroundColor "Red"
    }
}


Write-Log -LogFile $LogFile -Message "--------------------------------------------------------------------"

Write-Log -LogFile $LogFile -Message "Executing script $ScriptName"
Write-Log -LogFile $LogFile -Message "Value of type parameter : $Type"

# Setting $SourceFile based on $Type parameter value
# Each pointing to an image file
switch ($Type) {
    'INSTALL_OK' {
        $SourceFile = "$ScriptPath\Images\INSTALL_OK.png"
        Write-Log -LogFile $LogFile -Message "Setup of lockscreen - Installation Successful : $SourceFile"
    }
    'RESET' {
        Write-Log -LogFile $LogFile -Message "Reset of lockscreen"
    }
}

# Reset parameter is used to remove the registry key
If ($Type -eq "RESET") {

    If (Test-Path -Path $RegistryPath -PathType "Container") {
        Write-Log -LogFile $LogFile -Message "Registry key $RegistryPath exist => Removing"
        Remove-Item -Path $RegistryPath -Force -ErrorAction "Stop"
        Write-Log -LogFile $LogFile -Message "    . Key deleted"
    }
    Else {
        Write-Log -LogFile $LogFile -Message "Registry key $RegistryPath does not exist => Nothing to do"
    }

}
else {

    # Check if the registry key exists, if not it's created
    If (test-path -Path $RegistryPath -PathType "Container") {
        Write-Log -LogFile $LogFile -Message "Registry key $RegistryPath already exist => Nothing to do"
    }
    Else {
        Write-Log -LogFile $LogFile -Message "Registry key $RegistryPath does not exist => Create"
        Try {
            New-Item -Path $RegistryPath -Force -ErrorAction "Stop" | Out-Null
            Write-Log -LogFile $LogFile -Message "    . Registry key Created"
        }
        Catch {
            Write-Log -LogFile $LogFile -Type "Error" -Message "Fail to create registry key - $_"
            Exit-Error
        }
    }

    # Check if local directory exists, if not it's created
    if (-not(Test-Path -Path (Split-Path -Path $Destfile -Parent) -PathType Container)) {
        Write-Log -LogFile $LogFile -Message "Directory $(Split-Path -Path $Destfile -Parent) does not exist => Create"
        New-Item -Path $(Split-Path -Path $Destfile -Parent) -ItemType "Directory" -Force -ErrorAction "Stop" | Out-Null
        Write-Log -LogFile $LogFile -Message "    . Directory created"
    }
    else {
        Write-Log -LogFile $LogFile -Message "Directory $(Split-Path -Path $Destfile -Parent) already exists"
    }

    # Copy picture to the directory
    Try {
        Write-Log -LogFile $LogFile -Message "Copy of file $SourceFile to $Destfile"
        Copy-Item -Path $SourceFile -Destination $Destfile -Force -ErrorAction "Stop" | Out-Null
        Write-Log -LogFile $LogFile -Message "    . File copied"
    }
    Catch {
        Write-Log -LogFile $LogFile -Type "Error" -Message "    . Failed to copy file  - $_"
        Exit-Error
    }

    # Set registry key with the picture path
    Try {
        Write-Log -LogFile $LogFile -Message "Write registry value LockScreenImagePath to $Destfile"
        New-ItemProperty -Path $RegistryPath -Name "LockScreenImagePath" -Value $Destfile -PropertyType "STRING" -Force -ErrorAction "Stop" | Out-Null
        Write-Log -LogFile $LogFile -Message "    . Value written"
    }
    Catch {
        Write-Log -LogFile $LogFile -Type "Error" -Message "Fail to write registry value LockScreenImagePath - $_"
        Exit-Error
    }

    # Set registry key to apply the lockscreen
    Try {
        Write-Log -LogFile $LogFile -Message "Write registry value LockScreenImageStatus to 1"
        Set-ItemProperty -Path $RegistryPath -Name "LockScreenImageStatus" -Value 1 -Force -ErrorAction "Stop" | Out-Null
        Write-Log -LogFile $LogFile -Message "    . Value written"
    }
    Catch {
        Write-Log -LogFile $LogFile -Type "Error" -Message "Fail to write registry value LockScreenImageStatus - $_"
        Exit-Error
    }

}


Write-Log -LogFile $LogFile -Message "Script ended successfully"
Write-Log -LogFile $LogFile -Message "--------------------------------------------------------------------"
