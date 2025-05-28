#Create Path
New-Item -Path "C:\" -Name "temp" -ItemType "Directory"

# Download the latest Chrome installer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/spoddar13/azure_imagebuilder_2025/main/software/ChromeSetup.exe" -OutFile "C:\temp\ChromeSetup.exe"

# Silent installation
Start-Process "C:\temp\ChromeSetup.exe" -ArgumentList "/silent /install" -Wait

# Disable Chrome's Auto-Update Check
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Update" -Name "AutoUpdateCheckPeriodMinutes" -PropertyType DWORD -Value 0 -Force

# Stop the Google Update Service
Stop-Service -Name "Google Update Service" -ErrorAction SilentlyContinue

# Disable the Google Update Service startup
Set-Service -Name "Google Update Service" -StartupType Disabled -ErrorAction SilentlyContinue

# Modify the registry to disable automatic update checks
New-Item -Path "HKLM:\SOFTWARE\Policies\Google\Update" -ErrorAction SilentlyContinue

#RemovePath
Remove-Item -Path "C:\temp" -Force -Recurse
