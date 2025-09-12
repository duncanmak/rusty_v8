# This script downloads and installs the x64 dbghelp.dll from the Windows SDK ISO
# It is needed because of this note here:
# https://chromium.googlesource.com/chromium/src/+/refs/heads/main/docs/windows_build_instructions.md#Visual-Studio

$isoPath = "$env:TEMP\winsdk.iso"

function Get-ISO {
    Write-Host "Downloading and mounting Windows SDK ISO..."

    # Keep in sync with https://github.com/actions/partner-runner-images/blob/main/images/arm-windows-11-image.md
    # Windows SDK for Windows 11 (10.0.26100.4654)
    $isoUrl = "https://go.microsoft.com/fwlink/?linkid=2326092"
    
    # Download the ISO
    Invoke-WebRequest -Uri $isoUrl -OutFile $isoPath

    # Mount the ISO
    $mountResult = Mount-DiskImage -ImagePath $isoPath -PassThru

    # Return the drive letter
    return ($mountResult | Get-Volume).DriveLetter + ":"
}

function Main {
    try {
        if (-not (Test-Path "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\dbghelp.dll")) {
            $driveLetter = Get-ISO

            # install lessmsi using chocolatey
            &"choco" "install" "lessmsi" "-y"

            # Extract dbghelp.dll from the MSI
            &"lessmsi" "x" "$driveLetter\Installers\X64 Debuggers And Tools-x64_en-us.msi" "$env:TEMP\"

            # Copy dbghelp.dll to the destination
            $source = "$env:TEMP\SourceDir\Windows Kits\10\Debuggers\x64\dbghelp.dll"
            $destination = "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\"

            Get-ChildItem $source -ErrorAction Stop

            # Ensure destination directory exists
            if (-not (Test-Path $destination)) {
                New-Item -ItemType Directory -Force -Path $destination -Verbose
            }

            Copy-Item -Path $source -Destination "$destination\dbghelp.dll" -Force -Verbose
        }
        # Assert that dbghelp.dll is in the right place
        Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\dbghelp.dll" -ErrorAction Stop
    }
    finally {
        Dismount-DiskImage -ImagePath $isoPath > $null
    }
}

Main