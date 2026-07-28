<#
.SYNOPSIS
Validates the AzUrlShortener Entra + Managed Identity setup used by TinyBlazorAdmin and Api.

.DESCRIPTION
Run this script after deployment to verify that the key configuration matches the working setup:
- App registrations and service principals exist
- API app roles exist
- Admin app optional claims include roles
- Federated identity credential matches managed identity principal
- Admin managed identity has expected app-role assignment(s) on API
- Admin Container App has expected managed identity and environment variables

REQUIREMENTS
- Azure CLI logged in: az login
- Permissions to read Entra apps/SPs and Container Apps
- Microsoft Graph permissions for your signed-in principal (directory read and appRoleAssignment read)

USAGE
1) Fill values in the CONFIGURATION block.
2) Run: pwsh ./tools/validate-setup.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =====================
# CONFIGURATION
# =====================
# Fill all values below before running.
# Tip: Keep this file as a template and copy it to validate-setup.local.ps1 for personal values.
#
# Quick lookup commands:
# - Current tenant id:
#   az account show --query tenantId -o tsv
# - App registration client id by display name:
#   az ad app list --display-name "<APP_DISPLAY_NAME>" --query "[0].appId" -o tsv
# - Service principal object id by app id:
#   az ad sp list --filter "appId eq '<APP_OR_MI_CLIENT_ID>'" --query "[0].id" -o tsv
# - User-assigned managed identity details:
#   az identity show -g <RESOURCE_GROUP_NAME> -n <MANAGED_IDENTITY_NAME> --query "{clientId:clientId,principalId:principalId,id:id}" -o json

# Tenant
# Entra tenant id (GUID)
$TenantId = "<TENANT_ID>"

# Azure resources
# Resource group where admin/api Container Apps are deployed
$ResourceGroupName = "<RESOURCE_GROUP_NAME>"
# Container App name for TinyBlazorAdmin
$AdminContainerAppName = "<ADMIN_CONTAINER_APP_NAME>"
# Container App name for API
$ApiContainerAppName = "<API_CONTAINER_APP_NAME>"

# Admin app registration
# Client ID (appId) from Entra App registrations -> admin app
$AdminAppClientId = "<ADMIN_APP_CLIENT_ID>"
# Display name of the same app registration (used as a sanity check)
$AdminAppDisplayName = "<ADMIN_APP_DISPLAY_NAME>"

# API app registration
# Client ID (appId) from Entra App registrations -> API app
$ApiAppClientId = "<API_APP_CLIENT_ID>"
# Display name of the same API app registration
$ApiAppDisplayName = "<API_APP_DISPLAY_NAME>"

# Managed identity attached to admin container app (user-assigned)
# IMPORTANT:
# - ManagedIdentityClientId = managed identity application/client id (appId)
# - ManagedIdentityPrincipalId = managed identity object/principal id (service principal object id)
# These are different values.
$ManagedIdentityClientId = "<MANAGED_IDENTITY_CLIENT_ID>"
$ManagedIdentityPrincipalId = "<MANAGED_IDENTITY_PRINCIPAL_ID>"
# Full Azure resource id of the user-assigned managed identity
$ManagedIdentityResourceId = "<MANAGED_IDENTITY_RESOURCE_ID>"

# Optional: set when you explicitly want to validate the container app's identity.principalId
# Leave empty to skip because this may represent a system-assigned identity when both identity types are enabled.
$ExpectedAdminContainerPrincipalId = ""

# Federated identity credential expectations (Admin app)
# Federated credential name configured on the admin app registration
$ExpectedFederatedCredentialName = "<FEDERATED_CREDENTIAL_NAME>"
# For Azure Global cloud this is usually api://AzureADTokenExchange
$ExpectedFederatedAudience = "api://AzureADTokenExchange"

# Required API app role values
# These are the appRole "value" fields on the API app registration.
$RequiredApiRoleValues = @("UrlCreator", "UrlManager", "Admin")

# Required role assignment(s) for the managed identity on the API enterprise app
# Example: @("Admin") or @("UrlCreator") or @("Admin", "UrlManager")
# Use API app role values (not role display names, not role ids).
$RequiredManagedIdentityToApiRoleAssignments = @("<API_APP_ROLE_VALUE>")

# =====================
# IMPLEMENTATION
# =====================

$checkResults = New-Object System.Collections.Generic.List[object]

function Add-CheckResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Details
    )

    $status = if ($Passed) { "PASS" } else { "FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }
    Write-Host ("[{0}] {1} - {2}" -f $status, $Name, $Details) -ForegroundColor $color

    $checkResults.Add([pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Details = $Details
    }) | Out-Null
}

function Ensure-NotPlaceholder {
    param(
        [string]$Name,
        [string]$Value,
        [bool]$AllowEmpty = $false
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($AllowEmpty) {
            return
        }
        throw "Configuration value '$Name' is empty. Fill it before running the script."
    }

    if ($Value -match '^<.+>$') {
        throw "Configuration value '$Name' still contains a placeholder: $Value"
    }
}

function Get-JsonFromAz {
    param(
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $raw = & az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        if (-not $AllowFailure) {
            Write-Host ("[WARN] az {0}`n{1}" -f ($Arguments -join " "), ($raw -join [Environment]::NewLine)) -ForegroundColor Yellow
        }
        return $null
    }

    $text = $raw -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text | ConvertFrom-Json
}

function Test-ContainsAll {
    param(
        [string[]]$Source,
        [string[]]$Required
    )

    foreach ($item in $Required) {
        if ($Source -notcontains $item) {
            return $false
        }
    }
    return $true
}

Write-Host "=== AzUrlShortener setup validation ===" -ForegroundColor Cyan
Write-Host ""

Ensure-NotPlaceholder -Name "TenantId" -Value $TenantId
Ensure-NotPlaceholder -Name "ResourceGroupName" -Value $ResourceGroupName
Ensure-NotPlaceholder -Name "AdminContainerAppName" -Value $AdminContainerAppName
Ensure-NotPlaceholder -Name "ApiContainerAppName" -Value $ApiContainerAppName
Ensure-NotPlaceholder -Name "AdminAppClientId" -Value $AdminAppClientId
Ensure-NotPlaceholder -Name "ApiAppClientId" -Value $ApiAppClientId
Ensure-NotPlaceholder -Name "ManagedIdentityClientId" -Value $ManagedIdentityClientId
Ensure-NotPlaceholder -Name "ManagedIdentityPrincipalId" -Value $ManagedIdentityPrincipalId
Ensure-NotPlaceholder -Name "ExpectedFederatedCredentialName" -Value $ExpectedFederatedCredentialName
Ensure-NotPlaceholder -Name "ExpectedFederatedAudience" -Value $ExpectedFederatedAudience

if ($RequiredApiRoleValues.Count -eq 0) {
    throw "RequiredApiRoleValues must contain at least one role value."
}
if ($RequiredManagedIdentityToApiRoleAssignments.Count -eq 0) {
    throw "RequiredManagedIdentityToApiRoleAssignments must contain at least one role value."
}

$account = Get-JsonFromAz -Arguments @("account", "show", "-o", "json")
Add-CheckResult -Name "Azure login context" -Passed ($null -ne $account) -Details "Current account loaded"

if ($null -ne $account) {
    Add-CheckResult -Name "Tenant match" -Passed ($account.tenantId -eq $TenantId) -Details ("Current tenant={0}, expected={1}" -f $account.tenantId, $TenantId)
}

$adminApp = Get-JsonFromAz -Arguments @("ad", "app", "list", "--filter", "appId eq '$AdminAppClientId'", "-o", "json") | Select-Object -First 1
$apiApp = Get-JsonFromAz -Arguments @("ad", "app", "list", "--filter", "appId eq '$ApiAppClientId'", "-o", "json") | Select-Object -First 1

Add-CheckResult -Name "Admin app registration exists" -Passed ($null -ne $adminApp) -Details ("appId={0}" -f $AdminAppClientId)
Add-CheckResult -Name "API app registration exists" -Passed ($null -ne $apiApp) -Details ("appId={0}" -f $ApiAppClientId)

if ($null -ne $adminApp -and -not [string]::IsNullOrWhiteSpace($AdminAppDisplayName)) {
    Add-CheckResult -Name "Admin app display name" -Passed ($adminApp.displayName -eq $AdminAppDisplayName) -Details ("actual={0}, expected={1}" -f $adminApp.displayName, $AdminAppDisplayName)
}

if ($null -ne $apiApp -and -not [string]::IsNullOrWhiteSpace($ApiAppDisplayName)) {
    Add-CheckResult -Name "API app display name" -Passed ($apiApp.displayName -eq $ApiAppDisplayName) -Details ("actual={0}, expected={1}" -f $apiApp.displayName, $ApiAppDisplayName)
}

$apiRoleValues = @()
if ($null -ne $apiApp -and $null -ne $apiApp.appRoles) {
    $apiRoleValues = @($apiApp.appRoles | Where-Object { $_.isEnabled -eq $true } | ForEach-Object { $_.value })
}
Add-CheckResult -Name "API required role values" -Passed (Test-ContainsAll -Source $apiRoleValues -Required $RequiredApiRoleValues) -Details ("found={0}" -f (($apiRoleValues | Sort-Object) -join ", "))

if ($null -ne $adminApp) {
    $idTokenClaims = @($adminApp.optionalClaims.idToken | ForEach-Object { $_.name })
    $accessTokenClaims = @($adminApp.optionalClaims.accessToken | ForEach-Object { $_.name })

    $hasRolesInIdToken = $idTokenClaims -contains "roles"
    $hasRolesInAccessToken = $accessTokenClaims -contains "roles"

    Add-CheckResult -Name "Admin optional claims (idToken roles)" -Passed $hasRolesInIdToken -Details ("idToken claims={0}" -f ($idTokenClaims -join ", "))
    Add-CheckResult -Name "Admin optional claims (accessToken roles)" -Passed $hasRolesInAccessToken -Details ("accessToken claims={0}" -f ($accessTokenClaims -join ", "))

    $ficList = Get-JsonFromAz -Arguments @("rest", "--method", "GET", "--url", "https://graph.microsoft.com/v1.0/applications/$($adminApp.id)/federatedIdentityCredentials", "-o", "json")
    $fic = $null
    if ($null -ne $ficList -and $null -ne $ficList.value) {
        $fic = $ficList.value | Where-Object { $_.name -eq $ExpectedFederatedCredentialName } | Select-Object -First 1
    }

    Add-CheckResult -Name "Federated credential exists" -Passed ($null -ne $fic) -Details ("name={0}" -f $ExpectedFederatedCredentialName)

    if ($null -ne $fic) {
        $expectedIssuer = "https://login.microsoftonline.com/$TenantId/v2.0"
        Add-CheckResult -Name "Federated credential issuer" -Passed ($fic.issuer -eq $expectedIssuer) -Details ("actual={0}, expected={1}" -f $fic.issuer, $expectedIssuer)
        Add-CheckResult -Name "Federated credential subject" -Passed ($fic.subject -eq $ManagedIdentityPrincipalId) -Details ("actual={0}, expected={1}" -f $fic.subject, $ManagedIdentityPrincipalId)
        Add-CheckResult -Name "Federated credential audience" -Passed ($fic.audiences -contains $ExpectedFederatedAudience) -Details ("audiences={0}" -f (($fic.audiences) -join ", "))
    }
}

$adminSp = Get-JsonFromAz -Arguments @("ad", "sp", "list", "--filter", "appId eq '$AdminAppClientId'", "-o", "json") | Select-Object -First 1
$apiSp = Get-JsonFromAz -Arguments @("ad", "sp", "list", "--filter", "appId eq '$ApiAppClientId'", "-o", "json") | Select-Object -First 1
$miSp = Get-JsonFromAz -Arguments @("ad", "sp", "show", "--id", "$ManagedIdentityPrincipalId", "-o", "json")
$miSpByClientId = Get-JsonFromAz -Arguments @("ad", "sp", "list", "--filter", "appId eq '$ManagedIdentityClientId'", "-o", "json") | Select-Object -First 1

Add-CheckResult -Name "Admin service principal exists" -Passed ($null -ne $adminSp) -Details ("appId={0}" -f $AdminAppClientId)
Add-CheckResult -Name "API service principal exists" -Passed ($null -ne $apiSp) -Details ("appId={0}" -f $ApiAppClientId)
Add-CheckResult -Name "Managed identity service principal exists" -Passed ($null -ne $miSp) -Details ("objectId={0}" -f $ManagedIdentityPrincipalId)
Add-CheckResult -Name "Managed identity appId exists" -Passed ($null -ne $miSpByClientId) -Details ("appId={0}" -f $ManagedIdentityClientId)

if ($null -ne $miSp) {
    Add-CheckResult -Name "Managed identity clientId" -Passed ($miSp.appId -eq $ManagedIdentityClientId) -Details ("actual={0}, expected={1}" -f $miSp.appId, $ManagedIdentityClientId)

    if ($ManagedIdentityClientId -eq $ManagedIdentityPrincipalId) {
        Add-CheckResult -Name "Managed identity IDs sanity" -Passed $false -Details "ManagedIdentityClientId equals ManagedIdentityPrincipalId. ClientId should be appId (for example $($miSp.appId)), not objectId."
    }
}

if ($null -ne $miSpByClientId) {
    Add-CheckResult -Name "Managed identity objectId matches clientId" -Passed ($miSpByClientId.id -eq $ManagedIdentityPrincipalId) -Details ("objectId for appId={0} is {1}; expected={2}" -f $ManagedIdentityClientId, $miSpByClientId.id, $ManagedIdentityPrincipalId)
}

if ($null -ne $apiApp -and $null -ne $apiSp -and $null -ne $miSp) {
    $assignmentResult = Get-JsonFromAz -Arguments @("rest", "--method", "GET", "--url", "https://graph.microsoft.com/v1.0/servicePrincipals/$($miSp.id)/appRoleAssignments?`$filter=resourceId eq $($apiSp.id)", "-o", "json")
    $assignments = @()
    if ($null -ne $assignmentResult -and $null -ne $assignmentResult.value) {
        $assignments = @($assignmentResult.value)
    }

    $apiRolesById = @{}
    foreach ($role in $apiApp.appRoles) {
        if (-not [string]::IsNullOrWhiteSpace($role.id) -and -not [string]::IsNullOrWhiteSpace($role.value)) {
            $apiRolesById[$role.id.ToString().ToLowerInvariant()] = $role.value
        }
    }

    $assignedRoleValues = @()
    foreach ($a in $assignments) {
        $key = $a.appRoleId.ToString().ToLowerInvariant()
        if ($apiRolesById.ContainsKey($key)) {
            $assignedRoleValues += $apiRolesById[$key]
        }
    }

    foreach ($requiredRole in $RequiredManagedIdentityToApiRoleAssignments) {
        $hasAssignment = $assignedRoleValues -contains $requiredRole
        Add-CheckResult -Name ("MI -> API role assignment ({0})" -f $requiredRole) -Passed $hasAssignment -Details ("assigned roles={0}" -f (($assignedRoleValues | Sort-Object -Unique) -join ", "))
    }
}

$adminContainer = Get-JsonFromAz -Arguments @("containerapp", "show", "-g", "$ResourceGroupName", "-n", "$AdminContainerAppName", "-o", "json")
$apiContainer = Get-JsonFromAz -Arguments @("containerapp", "show", "-g", "$ResourceGroupName", "-n", "$ApiContainerAppName", "-o", "json")

Add-CheckResult -Name "Admin container app exists" -Passed ($null -ne $adminContainer) -Details ("name={0}" -f $AdminContainerAppName)
Add-CheckResult -Name "API container app exists" -Passed ($null -ne $apiContainer) -Details ("name={0}" -f $ApiContainerAppName)

if ($null -ne $adminContainer) {
    $adminPrincipalIdActual = $adminContainer.identity.principalId
    if (-not [string]::IsNullOrWhiteSpace($ExpectedAdminContainerPrincipalId)) {
        Add-CheckResult -Name "Admin container principalId" -Passed ($adminPrincipalIdActual -eq $ExpectedAdminContainerPrincipalId) -Details ("actual={0}, expected={1}" -f $adminPrincipalIdActual, $ExpectedAdminContainerPrincipalId)
    }
    else {
        Add-CheckResult -Name "Admin container principalId (info)" -Passed $true -Details ("actual={0}. Validation skipped (set ExpectedAdminContainerPrincipalId to enforce)." -f $adminPrincipalIdActual)
    }

    $uamiKeys = @()
    if ($null -ne $adminContainer.identity.userAssignedIdentities) {
        $uamiKeys = @($adminContainer.identity.userAssignedIdentities.PSObject.Properties.Name)
    }

    if (-not [string]::IsNullOrWhiteSpace($ManagedIdentityResourceId) -and -not ($ManagedIdentityResourceId -match '^<.+>$')) {
        Add-CheckResult -Name "Admin UAMI resource ID attached" -Passed ($uamiKeys -contains $ManagedIdentityResourceId) -Details ("attached={0}" -f ($uamiKeys -join ", "))
    }
    else {
        Add-CheckResult -Name "Admin has at least one UAMI" -Passed ($uamiKeys.Count -gt 0) -Details ("attached={0}" -f ($uamiKeys -join ", "))
    }

    $envItems = @($adminContainer.properties.template.containers[0].env)

    function Get-EnvValue {
        param([string]$Name)
        $match = $envItems | Where-Object { $_.name -eq $Name } | Select-Object -First 1
        if ($null -eq $match) { return $null }
        return $match.value
    }

    $envAzClientId = Get-EnvValue -Name "AZURE_CLIENT_ID"
    $envManagedIdentityClientId = Get-EnvValue -Name "AzureAd__ClientCredentials__0__ManagedIdentityClientId"
    $envDownstreamApiClientId = Get-EnvValue -Name "AzureAd__DownstreamApi__ApiClientId"

    Add-CheckResult -Name "Env AZURE_CLIENT_ID" -Passed ($envAzClientId -eq $ManagedIdentityClientId) -Details ("actual={0}, expected={1}" -f $envAzClientId, $ManagedIdentityClientId)
    Add-CheckResult -Name "Env AzureAd__ClientCredentials__0__ManagedIdentityClientId" -Passed ($envManagedIdentityClientId -eq $ManagedIdentityClientId) -Details ("actual={0}, expected={1}" -f $envManagedIdentityClientId, $ManagedIdentityClientId)

    if (-not [string]::IsNullOrWhiteSpace($envDownstreamApiClientId)) {
        Add-CheckResult -Name "Env AzureAd__DownstreamApi__ApiClientId" -Passed ($envDownstreamApiClientId -eq $ApiAppClientId) -Details ("actual={0}, expected={1}" -f $envDownstreamApiClientId, $ApiAppClientId)
    }
    else {
        Add-CheckResult -Name "Env AzureAd__DownstreamApi__ApiClientId" -Passed $true -Details "Not set (allowed if appsettings provides this value)."
    }
}

Write-Host ""
$failed = @($checkResults | Where-Object { -not $_.Passed })
$passedCount = @($checkResults | Where-Object { $_.Passed }).Count
$totalCount = $checkResults.Count

if ($failed.Count -eq 0) {
    Write-Host ("Validation completed: {0}/{1} checks passed." -f $passedCount, $totalCount) -ForegroundColor Green
    exit 0
}

Write-Host ("Validation completed: {0}/{1} checks passed." -f $passedCount, $totalCount) -ForegroundColor Yellow
Write-Host "Failed checks:" -ForegroundColor Red
foreach ($f in $failed) {
    Write-Host ("- {0}: {1}" -f $f.Name, $f.Details) -ForegroundColor Red
}

exit 1
