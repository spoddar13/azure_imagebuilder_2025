#Connect-AzAccount

#Get Timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

#Import module
Import-Module Az.Accounts

# Your subscription. This command gets your current subscription
#Set Subscription
$subscriptionID = (Get-AzContext).Subscription.Id
Set-AzContext -SubscriptionId $subscriptionID

# Destination image resource group
$imageResourceGroup = "RG-" + $timestamp

# Location (see possible locations in the main docs)
$location = "centralindia"

# Image template name
$imageTemplateName = "Win11AVDMultiSwithOffice"

# Distribution properties object name (runOutput). Gives you the properties of the managed image on completion
$runOutputName = "sigOutput"

# Create resource group
New-AzResourceGroup -Name $imageResourceGroup -Location $location

#setup role def names, these need to be unique
#$timeInt = $(get-date -UFormat "%s")
$imageRoleDefName = "AzureImageBuilderImageDef-" + $timestamp
$identityName = "MyIdentity" + $timestamp

## Add Azure PowerShell modules to support AzUserAssignedIdentity and Azure VM Image Builder
'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object { Install-Module -Name $_ -AllowPrerelease }

# Create the identity
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName -Location $location

#Store the identity resource and principal IDs in variables
$identityNameResourceId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id
$identityNamePrincipalId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).PrincipalId

Copy-Item -Path "./RoleImageTemplate.json" -Destination "./NewRoleImageCreation.json"
$myRoleImageCreationPath = "./NewRoleImageCreation.json"

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

$sigGalleryName = "MyImageGallary"
$imageDefName = "win11avdmultiWithOffice"

# Create the gallery
New-AzGallery -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup  -Location $location

# Create the gallery definition
New-AzGalleryImageDefinition -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup -Location $location -Name $imageDefName -OsState generalized -OsType 'Windows' -Publisher 'myCo' -Offer 'Windows' -Sku 'win11-24h2-avd-m365'


Copy-Item -Path "./RoleImageTemplate.json" -Destination "./NewArmTemplateWVD.json"
$templateFilePath = "./NewArmTemplateWVD.json"

Invoke-WebRequest -Uri $templateUrl -OutFile $templateFilePath -UseBasicParsing

((Get-Content -path $templateFilePath -Raw) -replace '<subscriptionID>', $subscriptionID) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region>', $location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<runOutputName>', $runOutputName) | Set-Content -Path $templateFilePath

((Get-Content -path $templateFilePath -Raw) -replace '<imageDefName>', $imageDefName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<sharedImageGalName>', $sigGalleryName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region1>', $location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imgBuilderId>', $identityNameResourceId) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace 'PlatformImageSKU', 'win11-24h2-avd-m365') | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace 'SKUOffer', 'office-365') | Set-Content -Path $templateFilePath

#staging resource group
New-AzResourceGroupDeployment -ResourceGroupName $imageResourceGroup -TemplateFile $templateFilePath -TemplateParameterObject @{"api-Version" = "2020-02-14"; "imageTemplateName" = $imageTemplateName; "svclocation" = $location }

# Optional - if you have any errors running the preceding command, run:
$getStatus = $(Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName)
$getStatus.ProvisioningErrorCode 
$getStatus.ProvisioningErrorMessage

Start-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName -NoWait

$getStatus = $(Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName)
# Shows all the properties
$getStatus | Format-List -Property *

# Shows the status of the build
$getStatus.LastRunStatusRunState 
$getStatus.LastRunStatusMessage
$getStatus.LastRunStatusRunSubState

#Delete Local Created Files
Remove-Item -Path $myRoleImageCreationPath -Force
Remove-Item -Path $templateFilePath -Force


