$isoPath = "$env:TEMP\winsdk.iso"

function Get-ISO {
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
    $driveLetter = Get-ISO

    # install lessmsi using chocolatey
    &"choco" install lessmsi -y

    # Extract dbghelp.dll from the MSI
    &"lessmsi" "x" "$driveLetter\Installers\X64 Debuggers And Tools-x64_en-us.msi" "$env:TEMP\"

    $source = "$env:TEMP\SourceDir\Windows Kits\10\Debuggers\x64\dbghelp.dll"
    $destination = "c:\Programs Files (x86)\Windows Kits\10\Debuggers\x64\dbghelp.dll"
    Copy-Item $source $destination

    Dismount-DiskImage -ImagePath $isoPath
}

Main