# This script sets up Azure resources for GitHub hosted runners
# Ensure Azure CLI is installed and available in PowerShell

# Stop on error
$ErrorActionPreference = "Stop"

# Set environment variables
$env:AZURE_LOCATION = "australiaeast"
$env:SUBSCRIPTION_ID = "8c6ccaa9-9f43-4f74-a91e-12a9f922d72c"
$env:RESOURCE_GROUP_NAME = "gh-runner-demo-rg-001"
$env:VNET_NAME = "gh-runner-demo-vnet-001"
$env:SUBNET_NAME = "gh-runner-demo-subnet-002"
$env:NSG_NAME = "gh-runner-demo-nsg-001"
$env:NETWORK_SETTINGS_RESOURCE_NAME = "gh-runner-demo-network-settings-001"
$env:DATABASE_ID = "166257474"
# $env:ADDRESS_PREFIX = "10.0.0.0/16"
# $env:SUBNET_PREFIX = "10.0.0.0/24"

# Log in to Azure (this may require manual interaction)
Write-Output "Login to Azure"
az login --output none

# Set account context
Write-Output "Set account context $env:SUBSCRIPTION_ID"
az account set --subscription $env:SUBSCRIPTION_ID

# Register resource provider GitHub.Network
Write-Output "Register resource provider GitHub.Network"
az provider register --namespace GitHub.Network

# Create resource group
# Write-Output "Create resource group $env:RESOURCE_GROUP_NAME at $env:AZURE_LOCATION"
# az group create --name $env:RESOURCE_GROUP_NAME --location $env:AZURE_LOCATION

# Create NSG rules deployed with 'actions-nsg-deployment.bicep' file
Write-Output "Create NSG rules deployed with 'actions-nsg-deployment.bicep' file"
az deployment group create --resource-group $env:RESOURCE_GROUP_NAME --template-file ./actions-nsg-deployment.bicep --parameters location=$env:AZURE_LOCATION nsgName=$env:NSG_NAME

# Create vnet and subnet
# Write-Output "Create vnet $env:VNET_NAME and subnet $env:SUBNET_NAME"
# az network vnet create --resource-group $env:RESOURCE_GROUP_NAME --name $env:VNET_NAME --address-prefix $env:ADDRESS_PREFIX --subnet-name $env:SUBNET_NAME --subnet-prefixes $env:SUBNET_PREFIX

# Delegate subnet to GitHub.Network/networkSettings and apply NSG rules
Write-Output "Delegate subnet to GitHub.Network/networkSettings and apply NSG rules"
az network vnet subnet update --resource-group $env:RESOURCE_GROUP_NAME --name $env:SUBNET_NAME --vnet-name $env:VNET_NAME --delegations "GitHub.Network/networkSettings" --network-security-group $env:NSG_NAME

# Create network settings resource
Write-Output "Create network settings resource $env:NETWORK_SETTINGS_RESOURCE_NAME"

$subnetId = "/subscriptions/$env:SUBSCRIPTION_ID/resourceGroups/$env:RESOURCE_GROUP_NAME/providers/Microsoft.Network/virtualNetworks/$env:VNET_NAME/subnets/$env:SUBNET_NAME"

$propertiesObject = @{
    location = $env:AZURE_LOCATION
    properties = @{
        subnetId = $subnetId
        businessId = $env:DATABASE_ID
    }
}

$jsonProperties = ($propertiesObject | ConvertTo-Json -Compress)
$jsonProperties = $jsonProperties | ConvertTo-Json

az resource create `
    --resource-group $env:RESOURCE_GROUP_NAME `
    --name $env:NETWORK_SETTINGS_RESOURCE_NAME `
    --resource-type "GitHub.Network/networkSettings" `
    --properties $jsonProperties `
    --is-full-object `
    --output table `
    --query "{GitHubId:tags.GitHubId, name:name}" `
    --api-version 2024-04-02

# Cleanup instruction
Write-Output "To clean up and delete resources run the following command:"
Write-Output "az group delete --resource-group $env:RESOURCE_GROUP_NAME"
