<#
.SYNOPSIS
  Convert a raw disk image (.img) to VHDX using `qemu-img` if available.

.DESCRIPTION
  Uses `qemu-img` to convert raw images to VHDX. If `qemu-img` is not installed
  the script prints instructions to install it (chocolatey/winget or manual).

.PARAMETER InputPath
  Path to the raw `.img` file.

.PARAMETER OutputPath
  Optional path for output VHDX. If omitted, input extension is replaced with `.vhdx`.

.EXAMPLE
  .\convert-to-vhdx.ps1 -InputPath C:\images\disk.img
  .\convert-to-vhdx.ps1 -InputPath C:\images\disk.img -OutputPath C:\out\disk.vhdx
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$InputPath,

    [string]$OutputPath
)

if (-not (Test-Path $InputPath)) {
    Write-Error "Input file not found: $InputPath"
    exit 2
}

if (-not $OutputPath) {
    $base = [IO.Path]::ChangeExtension($InputPath, '.vhdx')
    $OutputPath = $base
}

# find qemu-img
$qemu = Get-Command qemu-img.exe -ErrorAction SilentlyContinue
if (-not $qemu) {
    $alt = @("$env:ProgramFiles\qemu\qemu-img.exe","$env:ProgramFiles(x86)\qemu\qemu-img.exe")
    foreach ($p in $alt) { if (Test-Path $p) { $qemu = Get-Item $p; break } }
}

if (-not $qemu) {
    Write-Warning "qemu-img not found. Install qemu or use a conversion tool."
    Write-Output "Suggested installs:"
    Write-Output "  choco install qemu    # if you use Chocolatey"
    Write-Output "  winget install --id=Genuitec.Qemu  # or search winget for qemu packages"
    Write-Output "Or download qemu for Windows from the official site and add qemu-img to PATH."
    exit 3
}

Write-Output "Converting $InputPath -> $OutputPath using $($qemu.Path)"
try {
    $args = @('convert','-p','-f','raw','-O','vhdx', $InputPath, $OutputPath)
    $proc = Start-Process -FilePath $qemu.Path -ArgumentList $args -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -eq 0) { Write-Output "Conversion complete: $OutputPath" } else { Write-Warning "qemu-img exited with code $($proc.ExitCode)." }
} catch {
    Write-Error "Conversion failed: $_"
    exit 4
}
