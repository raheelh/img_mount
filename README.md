# img_mount helpers

This folder contains PowerShell helpers to mount, unmount, and convert raw disk images (.img) on Windows 10/11.

Files:

- `mount-image.ps1`: Convert a raw `.img` to VHDX and mount it using native Windows tooling.
- `unmount-image.ps1`: Unmount VHDX/DiskImage files or remove assigned drive letters using native Windows PowerShell commands.
- `convert-to-vhdx.ps1`: Convert raw `.img` to `.vhdx` using `qemu-img`.

Prerequisites

- Administrator privileges for mounting/unmounting and using PowerShell storage cmdlets.
- `qemu-img` (for converting to VHDX). Install via Chocolatey (`choco install qemu`) or download from the official qemu builds.

Mounting an image

Native (recommended, no kernel third-party driver): convert to VHDX and mount

```powershell
# Convert and mount using the helper (requires qemu-img and Mount-VHD/Mount-DiskImage)
.\mount-image.ps1 -ImagePath C:\path\to\disk.img

# Optionally provide an output VHDX path to keep the converted file
.\mount-image.ps1 -ImagePath C:\path\to\disk.img -OutputVhdPath C:\images\disk.vhdx
```

After running, Windows should show drive letters for partitions that have supported filesystems (NTFS/FAT/etc.). If you don't see drive letters, open Disk Management and ensure the virtual disk and partitions are online and have drive letters assigned.

Unmounting an image

The `unmount-image.ps1` helper supports native dismounting:

- `-VhdPath`: Dismount the attached VHDX or disk image using `Dismount-VHD` or `Dismount-DiskImage`.
- `-DriveLetters`: Remove one or more drive letters from mounted volumes when needed.

Examples:

```powershell
.\unmount-image.ps1 -VhdPath C:\path\to\disk.vhdx
.\unmount-image.ps1 -DriveLetters E,F
```

If the helper cannot perform the action automatically, use Disk Management or the native PowerShell dismount commands shown above.

Converting raw `.img` to VHDX

`convert-to-vhdx.ps1` uses `qemu-img` to convert a raw image to modern VHDX format.

```powershell
.\convert-to-vhdx.ps1 -InputPath C:\path\to\disk.img
.\convert-to-vhdx.ps1 -InputPath C:\path\to\disk.img -OutputPath C:\out\disk.vhdx
```

If `qemu-img` is not on PATH the script suggests installing it (Chocolatey/winget or manual download). Example `qemu-img` invocation used by the script:

```text
qemu-img convert -p -f raw -O vhdx input.img output.vhdx
```

After conversion you can attach the resulting `.vhdx` natively in Windows (right-click and "Mount" or use `Mount-VHD` / `Dismount-VHD` from the Hyper-V module) and browse partitions in File Explorer.

Security and notes

- Using native VHD mounting avoids third-party kernel-mode drivers.
- Converting large images may take significant disk space and time; ensure you have enough free space for the target `.vhdx`.
- If you prefer a solution without third-party drivers, convert to VHDX and use Windows' native VHD mounting (`Mount-VHD`) instead.

Next improvements

- Auto-detect and print the drive letters created when mounting.
- Add an `UnmountAllMountedVHD` helper that safely removes attached VHDs after confirming backing files.

Creating a raw image on Linux

To create a sector-for-sector raw image of a physical drive on Linux, use `dd` (or `ddrescue` for damaged media). Examples:

Basic copy (ensure you select the correct device):

```bash
sudo dd if=/dev/sdX of=./drive.img bs=4M status=progress conv=sync,noerror
```

Notes:

- Replace `/dev/sdX` with the device node for the target disk (e.g. `/dev/sda`). Double-check with `lsblk` or `fdisk -l`.
- Unmount any mounted partitions on the source drive before imaging.
- `bs=4M` improves throughput; `status=progress` shows progress on modern `dd`.
- `conv=sync,noerror` makes `dd` pad on read errors and continue copying.
- For better recovery on failing drives, prefer GNU `ddrescue`:

```bash
sudo ddrescue -f -n /dev/sdX drive.img drive.log
```

Compress on-the-fly to save space:

```bash
sudo dd if=/dev/sdX bs=4M status=progress | gzip -c > drive.img.gz
```

Or use `pv` to monitor progress while compressing:

```bash
sudo dd if=/dev/sdX bs=4M conv=sync,noerror | pv | gzip -c > drive.img.gz
```

After creating the raw `.img`, copy it to Windows and use the mount or convert helpers in this folder.

