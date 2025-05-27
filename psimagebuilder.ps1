#Connect-AzAccount

#Timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Step 1: Import module
Import-Module Az.Accounts

# Step 2: get existing context
#$currentAzContext = Get-AzContext

# Your subscription. This command gets your current subscription
#Set Subscription
$subscriptionID = (Get-AzContext).Subscription.Id
Set-AzContext -SubscriptionId $subscriptionID

# Destination image resource group
$imageResourceGroup = "RG-" + $timestamp

# Location (see possible locations in the main docs)
$location = "centralindia"

# Image template name
$imageTemplateName = "avd11ImageTemplate01"

# Distribution properties object name (runOutput). Gives you the properties of the managed image on completion
$runOutputName = "sigOutput"

# Create resource group
New-AzResourceGroup -Name $imageResourceGroup -Location $location

#setup role def names, these need to be unique
#$timeInt = $(get-date -UFormat "%s")
$imageRoleDefName = "Azure Image Builder Image Def-" + $timestamp
$identityName = "MyIdentity" + $timestamp

## Add Azure PowerShell modules to support AzUserAssignedIdentity and Azure VM Image Builder
'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object { Install-Module -Name $_ -AllowPrerelease }

# Create the identity
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName -Location $location

#Store the identity resource and principal IDs in variables
$identityNameResourceId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id
$identityNamePrincipalId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).PrincipalId

#Downlaod JSON config file to assign permissions to the identity
$myRoleImageCreationUrl = 'https://raw.githubusercontent.com/spoddar13/azure_imagebuilder_2025/main/RoleImageCreation.json'
$myRoleImageCreationPath = "myRoleImageCreation.json"
Invoke-WebRequest -Uri $myRoleImageCreationUrl -OutFile $myRoleImageCreationPath -UseBasicParsing



#update role definition template
$Content = Get-Content -Path $myRoleImageCreationPath -Raw
$Content = $Content -replace '<subscriptionID>', $subscriptionID
$Content = $Content -replace '<rgName>', $imageResourceGroup
$Content = $Content -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName 
$Content | Out-File -FilePath $myRoleImageCreationPath -Force

#Create role definition
New-AzRoleDefinition -InputFile $myRoleImageCreationPath

#Grant the role definition to the VM Image Builder service principal
$RoleAssignParams = @{
    ObjectId           = $identityNamePrincipalId
    RoleDefinitionName = $imageRoleDefName
    Scope              = "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"
}
New-AzRoleAssignment @RoleAssignParams


