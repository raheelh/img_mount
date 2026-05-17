<#
.SYNOPSIS
  Unmount a previously mounted raw image (ImDisk) by image path or drive letters.

.DESCRIPTION
  Attempts to unmount a raw image mounted via ImDisk Toolkit. Prefer passing
  `-ImagePath` (will try `mountimg.exe -d <image>`). You can also provide one
  or more `-DriveLetters` (e.g. 'E','F') to remove specific mounts via
  `imdisk.exe` if available.

.PARAMETER ImagePath
  Path to the image file that was mounted.

.PARAMETER DriveLetters
  One or more drive letters to unmount (letters only or with colon).

.EXAMPLE
  .\unmount-image.ps1 -DriveLetters E, F
  .\unmount-image.ps1 -ImagePath C:\images\disk.img
#>

[CmdletBinding()]
param(
	[string]$ImagePath,
	[string[]]$DriveLetters
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

# Locate helpers
$mountimg = Get-Command mountimg.exe -ErrorAction SilentlyContinue
if (-not $mountimg) {
	$possible = @("$env:ProgramFiles\ImDisk\mountimg.exe", "$env:ProgramFiles(x86)\ImDisk\mountimg.exe", "$env:ProgramFiles\ImDisk Toolkit\mountimg.exe", "$env:ProgramFiles(x86)\ImDisk Toolkit\mountimg.exe")
	foreach ($p in $possible) { if (Test-Path $p) { $mountimg = Get-Item $p; break } }
}

$imdisk = Get-Command imdisk.exe -ErrorAction SilentlyContinue
if (-not $imdisk) {
	$possible2 = @("$env:ProgramFiles\ImDisk\imdisk.exe", "$env:ProgramFiles(x86)\ImDisk\imdisk.exe", "$env:ProgramFiles\ImDisk Toolkit\imdisk.exe", "$env:ProgramFiles(x86)\ImDisk Toolkit\imdisk.exe")
	foreach ($p in $possible2) { if (Test-Path $p) { $imdisk = Get-Item $p; break } }
}

$didAnything = $false

if ($ImagePath) {
	if ($mountimg) {
		Write-Output "Attempting to unmount image using mountimg: $ImagePath"
		try {
			$proc = Start-Process -FilePath $mountimg.Path -ArgumentList '-d', '"' + $ImagePath + '"' -Wait -PassThru -WindowStyle Hidden
			if ($proc.ExitCode -eq 0) { Write-Output "Unmounted image: $ImagePath"; $didAnything = $true }
			else { Write-Warning "mountimg returned code $($proc.ExitCode)." }
		} catch {
			Write-Warning "Failed to run mountimg: $_"
		}
	} else {
		Write-Warning "mountimg.exe not found; cannot unmount by image path."
	}
}

if ($DriveLetters) {
	if (-not $imdisk) {
		Write-Warning "imdisk.exe not found; cannot unmount by drive letter via imdisk."
	} else {
		foreach ($d in $DriveLetters) {
			$letter = $d -replace ':',''
			Write-Output "Attempting to remove drive $letter via imdisk"
			try {
				$proc = Start-Process -FilePath $imdisk.Path -ArgumentList '-D', '-m', "$letter:`" -Wait -PassThru -WindowStyle Hidden
			} catch {
				# older imdisk uses syntax: imdisk -D -m X:\n+                $proc = Start-Process -FilePath $imdisk.Path -ArgumentList "-D -m $letter:`" -Wait -PassThru -WindowStyle Hidden
			}
			if ($proc -and $proc.ExitCode -eq 0) { Write-Output "Removed $letter:"; $didAnything = $true } else { Write-Warning "Failed to remove $letter (exit: $($proc.ExitCode))." }
		}
	}
}

if (-not $didAnything) {
	Write-Output "No automatic unmount performed. To unmount manually, open Disk Management or run the appropriate ImDisk commands."
	if ($imdisk) { Write-Output "Example: imdisk -D -m E:" }
	if ($mountimg) { Write-Output "Example: mountimg.exe -d \"C:\path\to\image.img\"" }
}
# Support native VHDX dismounting if requested
param(
    [string]$ImagePath,
    [string[]]$DriveLetters,
    [string]$VhdPath
)

if ($VhdPath) {
    if (Get-Command Dismount-VHD -ErrorAction SilentlyContinue) {
        try { Dismount-VHD -Path $VhdPath -Force; Write-Output "Dismounted VHD: $VhdPath"; $didAnything = $true } catch { Write-Warning "Failed to dismount VHD: $_" }
    } else {
        try { Dismount-DiskImage -ImagePath $VhdPath; Write-Output "Dismounted DiskImage: $VhdPath"; $didAnything = $true } catch { Write-Warning "Failed to dismount DiskImage: $_" }
    }
}

if ($didAnything) { Write-Output "Unmount actions completed." }
else { Write-Output "No VHDs or imdisk mounts were removed by this command." }