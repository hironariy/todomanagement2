# Azure Infrastructure Deployment Script for Todo Management App (PowerShell)
# This script deploys all infrastructure including VNet, PostgreSQL, Container Registry, and Container App Environment

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-todomanagement-dev",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "japaneast",
    
    [Parameter(Mandatory = $false)]
    [string]$Environment = "dev"
)

# Set error action
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Azure Infrastructure Deployment" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# Check if user is logged in
Write-Host "[0/4] Checking Azure authentication..." -ForegroundColor Yellow
$currentUser = az account show 2>$null
if (-not $currentUser) {
    Write-Host ""
    Write-Host "Not logged in. Please run: az login" -ForegroundColor Red
    Write-Host ""
    Write-Host "To log in, use:" -ForegroundColor Yellow
    Write-Host "  az login" -ForegroundColor Cyan
    exit 1
}

# Get and display current subscription
$subscription = $currentUser | ConvertFrom-Json
Write-Host "Logged in as: $($subscription.user.name)" -ForegroundColor Green
Write-Host ""
Write-Host "Current subscription:" -ForegroundColor Cyan
Write-Host "  Name: $($subscription.name)" -ForegroundColor Cyan
Write-Host "  ID:   $($subscription.id)" -ForegroundColor Cyan
Write-Host ""

# Ask user to confirm subscription
$confirmSub = Read-Host "Confirm using this subscription? (y/n, default y)"
if ($confirmSub -eq "n") {
    Write-Host ""
    Write-Host "To switch subscriptions:" -ForegroundColor Yellow
    Write-Host "  1. List all subscriptions: az account list --output table" -ForegroundColor Cyan
    Write-Host "  2. Select subscription: az account set --subscription <subscription-id>"  -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "Deployment Configuration:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "  Location:       $Location" -ForegroundColor Cyan
Write-Host "  Environment:    $Environment" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create Resource Group
Write-Host "[1/4] Creating Resource Group..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location
Write-Host "Resource Group created: $ResourceGroupName" -ForegroundColor Green
Write-Host ""

# Step 2: Deploy main infrastructure
Write-Host "[2/4] Deploying infrastructure..." -ForegroundColor Yellow
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$deploymentName = "infra-deployment-$timestamp"

az deployment group create `
    --name $deploymentName `
    --resource-group $ResourceGroupName `
    --template-file "main.bicep" `
    --parameters parameters.json

Write-Host "Infrastructure deployed" -ForegroundColor Green
Write-Host ""

# Step 3: Retrieve deployment outputs
Write-Host "[3/3] Retrieving deployment outputs..." -ForegroundColor Yellow

$outputsJson = az deployment group show `
    --name $deploymentName `
    --resource-group $ResourceGroupName `
    --query "properties.outputs" `
    -o json

if (-not $outputsJson -or $outputsJson -eq "null") {
    throw "Failed to retrieve deployment outputs for deployment '$deploymentName'."
}

$outputs = $outputsJson | ConvertFrom-Json

Write-Host "Deployment successful!" -ForegroundColor Green
Write-Host ""

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Infrastructure Details" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "PostgreSQL Server: $($outputs.postgresqlServerName.value)"
Write-Host "PostgreSQL Hostname: $($outputs.postgresqlHostname.value)"
Write-Host "Container Registry Login Server: $($outputs.containerRegistryLoginServer.value)"
Write-Host "Container Registry Name: $($outputs.containerRegistryName.value)"
Write-Host "Container App Environment: $($outputs.containerAppEnvironmentName.value)"
Write-Host "Database Name: $($outputs.databaseName.value)"
Write-Host "API_URL: $($outputs.containerAppApiUrl.value)"
Write-Host "WEB_URL: $($outputs.containerAppWebUrl.value)"
Write-Host ""
Write-Host "Web App Authentication:" -ForegroundColor Cyan
Write-Host "  AZURE_CLIENT_ID: $($outputs.appRegistrationAppId.value)"
Write-Host "  AZURE_TENANT_ID: $($outputs.azureTenantId.value)"

Write-Host "User Assigned Identity:" -ForegroundColor Cyan
Write-Host "  USER_ASSIGNED_IDENTITY_CLIENT_ID: $($outputs.userAssignedIdentityClientId.value)"
Write-Host "  USER_ASSIGNED_IDENTITY_RESOURCE_ID: $($outputs.userAssignedIdentityId.value)"
Write-Host "  USER_ASSIGNED_IDENTITY_NAME: $($outputs.userAssignedIdentityName.value)"
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Configure GitHub Actions for CI/CD"
Write-Host ""
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Deployment Completed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
