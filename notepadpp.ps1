#Create Path
New-Item -Path "C:\" -Name "temp" -ItemType "Directory"

# Download the latest Chrome installer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/spoddar13/azure_imagebuilder_2025/main/software/npp.8.8.1.Installer.x64.exe" -OutFile "C:\temp\npp.8.8.1.Installer.x64.exe"

# Silent installation
Start-Process -FilePath "C:\temp\npp.8.8.1.Installer.x64.exe" -Args "/S" -Verb RunAs -Wait
#RemovePath
Remove-Item -Path "C:\temp" -Force -Recurse