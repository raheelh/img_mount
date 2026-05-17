<#
.SYNOPSIS
  Unmount a mounted VHDX or attached disk image using native Windows PowerShell.

.DESCRIPTION
  This script removes drive letters from mounted partitions or dismounts an attached VHDX/disk image.
  It uses built-in `Dismount-VHD` / `Dismount-DiskImage` and native partition access path removal.

.PARAMETER DriveLetters
  One or more drive letters to remove (letters only or with colon).

.PARAMETER VhdPath
  Path to the attached VHDX or disk image to dismount.

.EXAMPLE
  .\unmount-image.ps1 -VhdPath C:\images\disk.vhdx
  .\unmount-image.ps1 -DriveLetters E,F
#>

[CmdletBinding()]
param(
    [string[]]$DriveLetters,
    [string]$VhdPath
)

function Test-Admin {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Output "Administrator privileges required. Re-launching as admin..."
    Start-Process -FilePath pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$didAnything = $false

if ($VhdPath) {
    if (Get-Command Dismount-VHD -ErrorAction SilentlyContinue) {
        try {
            Dismount-VHD -Path $VhdPath -Force
            Write-Output "Dismounted VHD: $VhdPath"
            $didAnything = $true
        } catch {
            Write-Warning "Failed to dismount VHD: $_"
        }
    } else {
        try {
            Dismount-DiskImage -ImagePath $VhdPath
            Write-Output "Dismounted DiskImage: $VhdPath"
            $didAnything = $true
        } catch {
            Write-Warning "Failed to dismount DiskImage: $_"
        }
    }
}

if ($DriveLetters) {
    foreach ($d in $DriveLetters) {
        $letter = ($d -replace ':','').ToUpper()
        try {
            $partition = Get-Partition -DriveLetter $letter -ErrorAction Stop
            Remove-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "$letter:`\" -ErrorAction Stop
            Write-Output "Removed drive letter $letter:`\"
            $didAnything = $true
        } catch {
            Write-Warning "Failed to remove drive letter $letter: $_"
        }
    }
}

if (-not $didAnything) {
    Write-Output "No automatic unmount performed. Use Disk Management, Dismount-VHD, or Dismount-DiskImage instead."
    Write-Output "Example: Dismount-VHD -Path C:\path\to\image.vhdx"
    Write-Output "Example: Dismount-DiskImage -ImagePath C:\path\to\image.vhdx"
}
