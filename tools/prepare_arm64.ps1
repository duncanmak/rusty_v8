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

function Copy-File {
    param (
        [string]$source,
        [string]$destination
    )
    # Use xcopy for robust copying and add error handling
    $xcopyCmd = "xcopy `"$source`" `"$destination`" /Y /C /V"
    $copyResult = cmd.exe /c $xcopyCmd

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$destination\dbghelp.dll")) {
        Write-Error "Failed to copy dbghelp.dll to $destination"
        exit 1
    } else {
        Write-Host "Successfully copied dbghelp.dll to $destination"
    }
}

function Main {
    try {
        $driveLetter = Get-ISO

        # install lessmsi using chocolatey
        &"choco" "install" "lessmsi" "-y"

        # Extract dbghelp.dll from the MSI
        &"lessmsi" "x" "$driveLetter\Installers\X64 Debuggers And Tools-x64_en-us.msi" "$env:TEMP\"

        # Copy dbghelp.dll to the destination
        $source = "$env:TEMP\SourceDir\Windows Kits\10\Debuggers\x64\dbghelp.dll"
        $destination = "C:\Programs Files (x86)\Windows Kits\10\Debuggers\x64\"

        # Ensure destination directory exists
        if (-not (Test-Path $destination)) {
            New-Item -Type Directory -Force -Path $destination | Out-Null
        }

        Copy-File $source "$destination\dbghelp.dll"

        # Assert that dbghelp.dll is in the right place
        if (-not (Test-Path "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\dbghelp.dll")) {
            Write-Error "dbghelp.dll does not exist for x64."
            exit 1
        }
    }
    finally {
        Dismount-DiskImage -ImagePath $isoPath
    }
}

Main