<#
.SYNOPSIS
Bootstraps TinyBlazorAdmin managed identity and Entra app wiring, then prints values for validate-setup.ps1.

.DESCRIPTION
This script automates the production setup steps for admin authentication:
- Resolves app registrations and managed identity IDs
- Ensures the admin container app has the user-assigned managed identity attached
- Sets admin container app environment variables for managed identity auth
- Creates/updates federated credential on the admin app registration
- Ensures optional claims include roles on id/access tokens
- Assigns API app role to the admin managed identity service principal
- Prints a ready-to-copy configuration block for validate-setup.ps1

REQUIREMENTS
- Azure CLI logged in (az login)
- Microsoft Graph permissions to read/update apps and role assignments
- Access to update Azure Container Apps and managed identities

USAGE EXAMPLES
pwsh ./tools/setup-admin-auth.ps1 -ResourceGroupName rg-myAzUrlShortener -ManagedIdentityName mi-fdkpaja47irka -AdminAppDisplayName adminAzUrlShortener -ApiAppDisplayName AzUrlShortener-Api

pwsh ./tools/setup-admin-auth.ps1 -ResourceGroupName rg-myAzUrlShortener -ManagedIdentityName mi-fdkpaja47irka -AdminAppClientId <guid> -ApiAppClientId <guid> -AdminContainerAppName admin -ApiRoleValue Admin

pwsh ./tools/setup-admin-auth.ps1 -ResourceGroupName rg-myAzUrlShortener -ManagedIdentityName mi-fdkpaja47irka -AdminAppDisplayName adminAzUrlShortener -ApiAppDisplayName AzUrlShortener-Api -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$AdminContainerAppName = "admin",

    [Parameter(Mandatory = $false)]
    [string]$ApiContainerAppName = "api",

    [Parameter(Mandatory = $false)]
    [string]$ManagedIdentityName,

    [Parameter(Mandatory = $false)]
    [string]$AdminAppClientId,

    [Parameter(Mandatory = $false)]
    [string]$AdminAppDisplayName,

    [Parameter(Mandatory = $false)]
    [string]$ApiAppClientId,

    [Parameter(Mandatory = $false)]
    [string]$ApiAppDisplayName,

    [Parameter(Mandatory = $false)]
    [string]$ApiRoleValue = "Admin",

    [Parameter(Mandatory = $false)]
    [string]$FederatedIdentityName = "adminAzUrlShortener-MI",

    [Parameter(Mandatory = $false)]
    [string]$FederatedAudience = "api://AzureADTokenExchange",

    [Parameter(Mandatory = $false)]
    [switch]$SkipOptionalClaimsPatch,

    [Parameter(Mandatory = $false)]
    [switch]$SkipApiRoleAssignment,

    [Parameter(Mandatory = $false)]
    [switch]$SkipContainerEnvUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:CurrentPsCmdlet = $PSCmdlet

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Assert-NotEmpty {
    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Missing required value for $Name."
    }
}

function Invoke-Change {
    param(
        [string]$Target,
        [string]$Action,
        [scriptblock]$ScriptBlock
    )

    if ($script:CurrentPsCmdlet.ShouldProcess($Target, $Action)) {
        & $ScriptBlock
        return $true
    }

    return $false
}

function Invoke-AzJson {
    param(
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $raw = & az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) {
            return $null
        }
        throw "az $($Arguments -join ' ') failed.`n$($raw -join [Environment]::NewLine)"
    }

    $text = $raw -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text | ConvertFrom-Json
}

function Invoke-AzText {
    param(
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $raw = & az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) {
            return $null
        }
        throw "az $($Arguments -join ' ') failed.`n$($raw -join [Environment]::NewLine)"
    }

    return ($raw -join [Environment]::NewLine).Trim()
}

function Resolve-AppRegistration {
    param(
        [string]$ClientId,
        [string]$DisplayName,
        [string]$Label
    )

    if (-not [string]::IsNullOrWhiteSpace($ClientId)) {
        $app = Invoke-AzJson -Arguments @("ad", "app", "list", "--filter", "appId eq '$ClientId'", "-o", "json") | Select-Object -First 1
        if ($null -eq $app) {
            throw "$Label app registration not found for ClientId=$ClientId"
        }
        return $app
    }

    if (-not [string]::IsNullOrWhiteSpace($DisplayName)) {
        $app = Invoke-AzJson -Arguments @("ad", "app", "list", "--display-name", "$DisplayName", "-o", "json") | Select-Object -First 1
        if ($null -eq $app) {
            throw "$Label app registration not found for DisplayName=$DisplayName"
        }
        return $app
    }

    throw "Provide either ${Label}AppClientId or ${Label}AppDisplayName."
}

function Set-FederatedCredential {
    param(
        [string]$AppObjectId,
        [string]$Name,
        [string]$Issuer,
        [string]$Subject,
        [string]$Audience
    )

    $ficList = Invoke-AzJson -Arguments @(
        "rest", "--method", "GET",
        "--url", "https://graph.microsoft.com/v1.0/applications/$AppObjectId/federatedIdentityCredentials",
        "-o", "json"
    )

    $existing = $null
    if ($null -ne $ficList -and $null -ne $ficList.value) {
        $existing = $ficList.value | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    }

    if ($null -eq $existing) {
        $payload = @{
            name = $Name
            issuer = $Issuer
            subject = $Subject
            description = "Trust admin UAMI for OIDC code redemption assertion"
            audiences = @($Audience)
        } | ConvertTo-Json -Depth 5

        $tmp = Join-Path $env:TEMP "fic-$Name.json"
        Set-Content -Path $tmp -Value $payload -Encoding UTF8

        $changed = Invoke-Change -Target "App registration $AppObjectId" -Action "Create federated credential '$Name'" -ScriptBlock {
            Invoke-AzText -Arguments @("ad", "app", "federated-credential", "create", "--id", "$AppObjectId", "--parameters", "@$tmp") | Out-Null
        }
        if ($changed) {
            Write-Host "Created federated credential '$Name'." -ForegroundColor Green
        }
        return
    }

    $needsUpdate = ($existing.issuer -ne $Issuer) -or ($existing.subject -ne $Subject) -or (-not ($existing.audiences -contains $Audience))
    if (-not $needsUpdate) {
        Write-Host "Federated credential '$Name' already matches expected values." -ForegroundColor Green
        return
    }

    $patch = @{
        issuer = $Issuer
        subject = $Subject
        audiences = @($Audience)
        description = "Trust admin UAMI for OIDC code redemption assertion"
    } | ConvertTo-Json -Depth 5

    $tmpPatch = Join-Path $env:TEMP "fic-$Name-patch.json"
    Set-Content -Path $tmpPatch -Value $patch -Encoding UTF8

    $updated = Invoke-Change -Target "App registration $AppObjectId" -Action "Update federated credential '$Name'" -ScriptBlock {
        Invoke-AzText -Arguments @(
            "rest", "--method", "PATCH",
            "--url", "https://graph.microsoft.com/v1.0/applications/$AppObjectId/federatedIdentityCredentials/$Name",
            "--headers", "Content-Type=application/json",
            "--body", "@$tmpPatch"
        ) | Out-Null
    }

    if ($updated) {
        Write-Host "Updated federated credential '$Name'." -ForegroundColor Yellow
    }
}

function Set-OptionalClaimsRoles {
    param([string]$AppObjectId)

    $payload = @{
        optionalClaims = @{
            idToken = @(@{ name = "roles"; essential = $false; additionalProperties = @() })
            accessToken = @(@{ name = "roles"; essential = $false; additionalProperties = @() })
        }
    } | ConvertTo-Json -Depth 10

    $tmp = Join-Path $env:TEMP "admin-optional-claims.json"
    Set-Content -Path $tmp -Value $payload -Encoding UTF8

    $changed = Invoke-Change -Target "App registration $AppObjectId" -Action "Patch optional claims (roles)" -ScriptBlock {
        Invoke-AzText -Arguments @(
            "rest", "--method", "PATCH",
            "--url", "https://graph.microsoft.com/v1.0/applications/$AppObjectId",
            "--headers", "Content-Type=application/json",
            "--body", "@$tmp"
        ) | Out-Null
    }

    if ($changed) {
        Write-Host "Ensured optional claims include roles for id/access tokens." -ForegroundColor Green
    }
}

function Set-ApiRoleAssignment {
    param(
        [string]$ManagedIdentityPrincipalId,
        [string]$ApiAppObjectId,
        [string]$ApiAppClientId,
        [string]$ApiRoleValue
    )

    $miSp = Invoke-AzJson -Arguments @("ad", "sp", "show", "--id", "$ManagedIdentityPrincipalId", "-o", "json")
    if ($null -eq $miSp) {
        throw "Managed identity service principal not found for objectId=$ManagedIdentityPrincipalId"
    }

    $apiSp = Invoke-AzJson -Arguments @("ad", "sp", "list", "--filter", "appId eq '$ApiAppClientId'", "-o", "json") | Select-Object -First 1
    if ($null -eq $apiSp) {
        throw "API service principal not found for appId=$ApiAppClientId"
    }

    $apiApp = Invoke-AzJson -Arguments @("ad", "app", "show", "--id", "$ApiAppObjectId", "-o", "json")
    $apiRole = $apiApp.appRoles | Where-Object { $_.value -eq $ApiRoleValue -and $_.isEnabled -eq $true } | Select-Object -First 1
    if ($null -eq $apiRole) {
        throw "API app role '$ApiRoleValue' not found/enabled on API app."
    }

    $existing = Invoke-AzJson -Arguments @(
        "rest", "--method", "GET",
        "--url", "https://graph.microsoft.com/v1.0/servicePrincipals/$($miSp.id)/appRoleAssignments?`$filter=resourceId eq $($apiSp.id)",
        "-o", "json"
    )

    $already = $false
    if ($null -ne $existing -and $null -ne $existing.value) {
        $already = @($existing.value | Where-Object { $_.appRoleId.ToString().ToLowerInvariant() -eq $apiRole.id.ToString().ToLowerInvariant() }).Count -gt 0
    }

    if ($already) {
        Write-Host "Managed identity already has API role '$ApiRoleValue'." -ForegroundColor Green
        return
    }

    $assignment = @{
        principalId = $miSp.id
        resourceId = $apiSp.id
        appRoleId = $apiRole.id
    } | ConvertTo-Json -Depth 5

    $tmp = Join-Path $env:TEMP "mi-api-approle-assignment.json"
    Set-Content -Path $tmp -Value $assignment -Encoding UTF8

    $assigned = Invoke-Change -Target "Service principal $($miSp.id)" -Action "Assign API role '$ApiRoleValue'" -ScriptBlock {
        Invoke-AzText -Arguments @(
            "rest", "--method", "POST",
            "--url", "https://graph.microsoft.com/v1.0/servicePrincipals/$($miSp.id)/appRoleAssignments",
            "--headers", "Content-Type=application/json",
            "--body", "@$tmp"
        ) | Out-Null
    }

    if ($assigned) {
        Write-Host "Assigned API role '$ApiRoleValue' to admin managed identity." -ForegroundColor Green
    }
}

Write-Step "Checking Azure CLI login context"
$account = Invoke-AzJson -Arguments @("account", "show", "-o", "json")
Assert-NotEmpty -Name "tenantId" -Value $account.tenantId

$tenantId = $account.tenantId
Write-Host "Tenant: $tenantId"

Write-Step "Resolving app registrations"
$adminApp = Resolve-AppRegistration -ClientId $AdminAppClientId -DisplayName $AdminAppDisplayName -Label "Admin"
$apiApp = Resolve-AppRegistration -ClientId $ApiAppClientId -DisplayName $ApiAppDisplayName -Label "Api"

$adminAppClientIdResolved = $adminApp.appId
$adminAppObjectId = $adminApp.id
$adminAppDisplayNameResolved = $adminApp.displayName

$apiAppClientIdResolved = $apiApp.appId
$apiAppObjectId = $apiApp.id
$apiAppDisplayNameResolved = $apiApp.displayName

Write-Host "Admin app: $adminAppDisplayNameResolved ($adminAppClientIdResolved)"
Write-Host "API app: $apiAppDisplayNameResolved ($apiAppClientIdResolved)"

Write-Step "Resolving admin container app and managed identity"
$adminContainer = Invoke-AzJson -Arguments @("containerapp", "show", "-g", "$ResourceGroupName", "-n", "$AdminContainerAppName", "-o", "json")

$managedIdentity = $null
if (-not [string]::IsNullOrWhiteSpace($ManagedIdentityName)) {
    $managedIdentity = Invoke-AzJson -Arguments @("identity", "show", "-g", "$ResourceGroupName", "-n", "$ManagedIdentityName", "-o", "json")
}
else {
    $uamiIds = @()
    if ($null -ne $adminContainer.identity.userAssignedIdentities) {
        $uamiIds = @($adminContainer.identity.userAssignedIdentities.PSObject.Properties.Name)
    }

    if ($uamiIds.Count -eq 0) {
        throw "No user-assigned identity attached to admin container app. Provide -ManagedIdentityName."
    }

    $managedIdentity = Invoke-AzJson -Arguments @("identity", "show", "--ids", "$($uamiIds[0])", "-o", "json")
}

$managedIdentityClientId = $managedIdentity.clientId
$managedIdentityPrincipalId = $managedIdentity.principalId
$managedIdentityResourceId = $managedIdentity.id
$managedIdentityNameResolved = $managedIdentity.name

Write-Host "Managed identity: $managedIdentityNameResolved"
Write-Host "  clientId:    $managedIdentityClientId"
Write-Host "  principalId: $managedIdentityPrincipalId"

Write-Step "Ensuring managed identity is attached to admin container app"
$identityAttached = Invoke-Change -Target "Container app $AdminContainerAppName" -Action "Attach managed identity $managedIdentityNameResolved" -ScriptBlock {
    Invoke-AzText -Arguments @(
        "containerapp", "identity", "assign",
        "-g", "$ResourceGroupName",
        "-n", "$AdminContainerAppName",
        "--user-assigned", "$managedIdentityResourceId",
        "-o", "none"
    ) | Out-Null
}
if ($identityAttached) {
    Write-Host "Managed identity attached to admin container app." -ForegroundColor Green
}

if (-not $SkipContainerEnvUpdate.IsPresent) {
    Write-Step "Setting admin container environment variables for managed identity"

    $envArgs = @(
        "containerapp", "update",
        "-g", "$ResourceGroupName",
        "-n", "$AdminContainerAppName",
        "--set-env-vars",
        "AZURE_CLIENT_ID=$managedIdentityClientId",
        "AzureAd__ClientCredentials__0__ManagedIdentityClientId=$managedIdentityClientId",
        "AzureAd__DownstreamApi__ApiClientId=$apiAppClientIdResolved",
        "-o", "none"
    )

    $envUpdated = Invoke-Change -Target "Container app $AdminContainerAppName" -Action "Update managed identity environment variables" -ScriptBlock {
        Invoke-AzText -Arguments $envArgs | Out-Null
    }
    if ($envUpdated) {
        Write-Host "Environment variables updated on admin container app." -ForegroundColor Green
    }
}
else {
    Write-Host "Skipped container environment variable updates." -ForegroundColor Yellow
}

Write-Step "Ensuring federated credential exists and matches expected values"
$issuer = "https://login.microsoftonline.com/$tenantId/v2.0"
Set-FederatedCredential -AppObjectId $adminAppObjectId -Name $FederatedIdentityName -Issuer $issuer -Subject $managedIdentityPrincipalId -Audience $FederatedAudience

if (-not $SkipOptionalClaimsPatch.IsPresent) {
    Write-Step "Ensuring optional claims for roles are configured"
    Set-OptionalClaimsRoles -AppObjectId $adminAppObjectId
}
else {
    Write-Host "Skipped optional claims patch." -ForegroundColor Yellow
}

if (-not $SkipApiRoleAssignment.IsPresent) {
    Write-Step "Ensuring admin managed identity has API app role assignment"
    Set-ApiRoleAssignment -ManagedIdentityPrincipalId $managedIdentityPrincipalId -ApiAppObjectId $apiAppObjectId -ApiAppClientId $apiAppClientIdResolved -ApiRoleValue $ApiRoleValue
}
else {
    Write-Host "Skipped API role assignment." -ForegroundColor Yellow
}

Write-Step "Collecting container details for validator"
$adminContainerFinal = Invoke-AzJson -Arguments @("containerapp", "show", "-g", "$ResourceGroupName", "-n", "$AdminContainerAppName", "-o", "json")
$adminContainerPrincipalId = $adminContainerFinal.identity.principalId

Write-Host ""
Write-Host "Copy the block below into tools/validate-setup.ps1 CONFIGURATION:" -ForegroundColor Cyan
Write-Host ""

@"
# Tenant
`$TenantId = "$tenantId"

# Azure resources
`$ResourceGroupName = "$ResourceGroupName"
`$AdminContainerAppName = "$AdminContainerAppName"
`$ApiContainerAppName = "$ApiContainerAppName"

# Admin app registration
`$AdminAppClientId = "$adminAppClientIdResolved"
`$AdminAppDisplayName = "$adminAppDisplayNameResolved"

# API app registration
`$ApiAppClientId = "$apiAppClientIdResolved"
`$ApiAppDisplayName = "$apiAppDisplayNameResolved"

# Managed identity attached to admin container app (user-assigned)
`$ManagedIdentityClientId = "$managedIdentityClientId"
`$ManagedIdentityPrincipalId = "$managedIdentityPrincipalId"
`$ManagedIdentityResourceId = "$managedIdentityResourceId"

# Optional: set when you explicitly want to validate the container app's identity.principalId
`$ExpectedAdminContainerPrincipalId = "$adminContainerPrincipalId"

# Federated identity credential expectations (Admin app)
`$ExpectedFederatedCredentialName = "$FederatedIdentityName"
`$ExpectedFederatedAudience = "$FederatedAudience"

# Required API app role values
`$RequiredApiRoleValues = @("UrlCreator", "UrlManager", "Admin")

# Required role assignment(s) for the managed identity on the API enterprise app
`$RequiredManagedIdentityToApiRoleAssignments = @("$ApiRoleValue")
"@ | Write-Host

Write-Host ""
Write-Host "Next: run pwsh ./tools/validate-setup.ps1 from src" -ForegroundColor Green
