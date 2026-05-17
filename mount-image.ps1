<#
.SYNOPSIS
  Mount a raw disk image (.img) on Windows by converting to VHDX and using native Windows mounting.

.DESCRIPTION
  This script converts a raw disk image to VHDX (using qemu-img) and mounts it read-only with Windows' built-in storage tooling.
  It does not require ImDisk Toolkit.

.PARAMETER ImagePath
  Path to the .img file to mount.

.PARAMETER Native
  Use the native conversion and mounting path.

.PARAMETER OutputVhdPath
  Optional output path for the generated VHDX file.

.EXAMPLE
  .\mount-image.ps1 -ImagePath C:\images\disk.img
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ImagePath,

    [switch]$Native,
    [string]$OutputVhdPath
)

function Test-Admin {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Path $ImagePath)) {
    Write-Error "Image path not found: $ImagePath"
    exit 2
}

if (-not (Test-Admin)) {
    Write-Output "Administrator privileges required. Re-launching as admin..."
    Start-Process -FilePath pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -ImagePath `"$ImagePath`"" -Verb RunAs
    exit
}


# Native VHDX conversion and mounting only.

# find qemu-img (for conversion)
$qemu = Get-Command qemu-img.exe -ErrorAction SilentlyContinue
if (-not $qemu) {
    $alt = @("$env:ProgramFiles\qemu\qemu-img.exe","$env:ProgramFiles(x86)\qemu\qemu-img.exe")
    foreach ($p in $alt) { if (Test-Path $p) { $qemu = Get-Item $p; break } }
}

# find native mount commands
$canMountVhd = Get-Command Mount-VHD -ErrorAction SilentlyContinue
$canMountDiskImage = Get-Command Mount-DiskImage -ErrorAction SilentlyContinue

if (-not $qemu) {
    Write-Error "Native path requires 'qemu-img'. Install qemu-img and retry."
    exit 6
}
if (-not $canMountVhd -and -not $canMountDiskImage) {
    Write-Error "No native mounting cmdlets found (Mount-VHD or Mount-DiskImage). Ensure you're running elevated and have the Storage/Hyper-V modules available."
    exit 7
}

# prepare VHDX path
$tempVhd = if ($OutputVhdPath) { $OutputVhdPath } else { [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetFileNameWithoutExtension($ImagePath) + "-tmp.vhdx") }
Write-Output "Converting raw image to VHDX: $tempVhd (this may take time)"
try {
    $args = @('convert','-p','-f','raw','-O','vhdx', $ImagePath, $tempVhd)
    $proc = Start-Process -FilePath $qemu.Path -ArgumentList $args -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) { Write-Error "qemu-img failed (code $($proc.ExitCode))."; exit 8 }
} catch {
    Write-Error "Failed to run qemu-img: $_"; exit 9
}

Write-Output "Mounting VHDX read-only: $tempVhd"
try {
    if ($canMountVhd) {
        $v = Mount-VHD -Path $tempVhd -ReadOnly -Passthru
        Start-Sleep -Seconds 1
        $disk = ($v | Get-Disk)
    } else {
        Mount-DiskImage -ImagePath $tempVhd
        Start-Sleep -Seconds 1
        $disk = Get-Disk | Where-Object { $_.Location -like "*${([IO.Path]::GetFileName($tempVhd))}*" } | Select-Object -First 1
    }
} catch {
    Write-Error "Failed to mount VHDX: $_"; exit 10
}

Write-Output "Mounted. Listing volumes for the attached disk:" 
if ($disk) {
    $diskNumber = $disk.Number
    Get-Partition -DiskNumber $diskNumber | ForEach-Object { Get-Volume -Partition $_ } | Format-Table DriveLetter, FileSystem, Size, SizeRemaining, FileSystemLabel -AutoSize
} else {
    Get-Volume | Where-Object FileSystemLabel -ne $null | Format-Table DriveLetter, FileSystem, Size, SizeRemaining, FileSystemLabel -AutoSize
}

Write-Output "If drive letters are missing, assign them with Set-Partition -DiskNumber <N> -PartitionNumber <P> -NewDriveLetter <L>"
Write-Output "Remember: temporary VHDX: $tempVhd (remove when done)."
