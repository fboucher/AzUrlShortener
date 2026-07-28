# Frequently asked questions (f.a.q.)

## Quick links

### Getting started and operations

- [How to run AzUrlShortener locally](#how-to-run-azurlshortener-locally)
- [How to deploy your AzUrlShortener](./how-to-deploy.md)
- [How to update/redeploy AzUrlShortener](#update-redeploy-azurlshortener)
- [How to migrate your data](./how-to-migrate-data.md)
- [How to validate setup configuration](#how-to-validate-setup-configuration)

### Configuration

- [How to add a custom domain](./how-to-add-custom-domain.md)
- [Add a custom domain to the admin website](./how-to-add-custom-domain.md#add-a-custom-domain-to-the-admin-website)
- [Add authentication to the admin website](./how-to-deploy.md#add-authentication-to-the-admin-website)
- [How to make the API public](./how-to-set-api-public.md)
- [Bootstrap admin auth setup with PowerShell](#bootstrap-admin-auth-setup-with-powershell)
- [How to configure admin auth with managed identity and app roles](#how-to-configure-admin-auth-with-managed-identity-and-app-roles)

### Reference

- [How does it work?](./how-it-works.md)
- [Security considerations](./security-considerations.md)


## How to run AzUrlShortener locally

You will need .NET 10, Docker or Podman installed on your machine. From the `src` directory, run the following command `dotnet run --project AppHost`. You can also open the solution in Visual Studio or Visual Studio Code and use F5, make sure the `Cloud5mins.ShortenerTools.AppHost` project is set as starting project.


## Update/ redeploy AzUrlShortener

In a terminal, navigate to the `src` directory of your project.

```bash
cd src
```

To avoid affecting custom domains when deploying Azure Container Apps use the following command. 

```bash
azd config set alpha.aca.persistDomains on
```

If you haven't already, log in to your Azure account with azd auth login. You can re-deploy the application with the following command:

```bash
azd up
```


## Bootstrap admin auth setup with PowerShell

To automate most of the managed identity and app registration wiring for TinyBlazorAdmin, use the setup helper script:

```powershell
cd src
pwsh ./tools/setup-admin-auth.ps1 -ResourceGroupName <RESOURCE_GROUP_NAME> -ManagedIdentityName <MANAGED_IDENTITY_NAME> -AdminAppDisplayName <ADMIN_APP_DISPLAY_NAME> -ApiAppDisplayName <API_APP_DISPLAY_NAME>
```

Preview changes only (no writes):

```powershell
cd src
pwsh ./tools/setup-admin-auth.ps1 -ResourceGroupName <RESOURCE_GROUP_NAME> -ManagedIdentityName <MANAGED_IDENTITY_NAME> -AdminAppDisplayName <ADMIN_APP_DISPLAY_NAME> -ApiAppDisplayName <API_APP_DISPLAY_NAME> -WhatIf
```

What it does:

- Resolves app IDs and object IDs for admin app, API app, and managed identity
- Attaches the user-assigned managed identity to the admin container app
- Sets admin container environment variables for managed identity usage
- Creates or updates the federated credential on the admin app registration
- Ensures optional claims include `roles` in ID and access tokens
- Assigns API app role (default `Admin`) to the admin managed identity
- Prints a ready-to-copy configuration block for `tools/validate-setup.ps1`

After it completes, run:

```powershell
cd src
pwsh ./tools/validate-setup.ps1
```


## How to configure admin auth with managed identity and app roles

This section documents the production setup used by TinyBlazorAdmin with Microsoft Entra ID, workload identity federation, and app roles.

### Prerequisites

1. Admin container app is deployed and has a user-assigned managed identity attached.
1. You know these values:
	 - Tenant ID
	 - Admin app registration Client ID
	 - Admin managed identity Client ID
	 - Admin managed identity Principal ID (Object ID)
1. You are signed in with an account that can manage app registrations and enterprise applications.

### 1) Create app roles on the app registration

In Microsoft Entra admin center:

1. Go to App registrations.
1. Open the admin app registration.
1. Open App roles.
1. Create roles with these exact values:
	 - UrlCreator
	 - UrlManager
	 - Admin

The role values must match what TinyBlazorAdmin checks in code.

### 2) Create federated credential that trusts the managed identity

Use Azure CLI with the app registration object ID.

```powershell
$appClientId = "<ADMIN_APP_CLIENT_ID>"
$tenantId = "<TENANT_ID>"
$miPrincipalId = "<MANAGED_IDENTITY_PRINCIPAL_ID>"

$appObjectId = az ad app list --filter "appId eq '$appClientId'" --query "[0].id" -o tsv

$fic = @{
	name = "adminAzUrlShortener-MI"
	issuer = "https://login.microsoftonline.com/$tenantId/v2.0"
	subject = $miPrincipalId
	description = "Trust admin UAMI for OIDC code redemption assertion"
	audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Depth 5

$path = Join-Path $env:TEMP "fic-admin-mi.json"
$fic | Set-Content -Path $path -Encoding UTF8
az ad app federated-credential create --id $appObjectId --parameters @$path
```

Important:

- subject must be the managed identity Principal ID (Object ID), not the client ID.
- issuer must match the tenant in v2.0 format.
- audience for global Azure must be api://AzureADTokenExchange.

### 3) Configure token optional claims for roles

```powershell
$appObjectId = "<APP_OBJECT_ID>"
$payload = @{
	optionalClaims = @{
		idToken = @(@{ name = "roles"; essential = $false; additionalProperties = @() })
		accessToken = @(@{ name = "roles"; essential = $false; additionalProperties = @() })
	}
} | ConvertTo-Json -Depth 10

$file = Join-Path $env:TEMP "admin-optional-claims.json"
Set-Content -Path $file -Value $payload -Encoding UTF8

az rest --method PATCH --url "https://graph.microsoft.com/v1.0/applications/$appObjectId" --headers "Content-Type=application/json" --body "@$file"
az ad app show --id $appObjectId --query optionalClaims -o json
```

### 4) Assign users (or groups) to app roles

In Enterprise applications:

1. Open the service principal for the admin app.
1. Go to Users and groups.
1. Assign your user (or a group) to one of:
	 - UrlCreator
	 - UrlManager
	 - Admin

### 5) Ensure the container app passes managed identity settings

Admin container app must include:

- AZURE_CLIENT_ID = user-assigned managed identity client ID
- AzureAd__ClientCredentials__0__ManagedIdentityClientId = user-assigned managed identity client ID

Verify with:

```powershell
$rg='rg-<your-env-name>'
$app='admin'
az containerapp show -g $rg -n $app --query "properties.template.containers[0].env[?name=='AzureAd__ClientCredentials__0__ManagedIdentityClientId' || name=='AZURE_CLIENT_ID']" -o table
```

### 6) Redeploy and reauthenticate

```bash
cd src
azd up
```

Then sign out and sign in again (new token issuance).

### 7) Authorize admin managed identity to call API

TinyBlazorAdmin calls the API using its managed identity. User roles in the UI are not enough for downstream app-to-app API authorization.

Assign an API app role (for example `Admin`) to the admin managed identity service principal:

```powershell
$apiAppId = "<API_APP_CLIENT_ID>"
$miSpId = "<ADMIN_MANAGED_IDENTITY_SERVICE_PRINCIPAL_ID>"

$apiSpId = az ad sp list --filter "appId eq '$apiAppId'" --query "[0].id" -o tsv
$apiAppObjectId = az ad app list --filter "appId eq '$apiAppId'" --query "[0].id" -o tsv
$apiAdminRoleId = az ad app show --id $apiAppObjectId --query "appRoles[?value=='Admin'] | [0].id" -o tsv

$assignment = @{
	principalId = $miSpId
	resourceId = $apiSpId
	appRoleId = $apiAdminRoleId
} | ConvertTo-Json -Depth 5

$assignmentFile = Join-Path $env:TEMP "mi-api-approle-assignment.json"
Set-Content -Path $assignmentFile -Value $assignment -Encoding UTF8

az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/$miSpId/appRoleAssignments" --headers "Content-Type=application/json" --body "@$assignmentFile"

az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$miSpId/appRoleAssignments?`$filter=resourceId eq $apiSpId" --query "value[].{appRoleId:appRoleId,resourceId:resourceId}" -o table
```

The final command should return at least one assignment row for the API resource.

### 8) Verification checklist

1. App revision updated.
1. Sign-in callback returns 302 to /.
1. Home page returns 200.
1. App log shows token validation with roles.
1. API calls from Url Manager return 200 (not 401).

```powershell
az containerapp logs show -g rg-<your-env-name> -n admin --tail 200
```

Look for a line like:

Token validated for <user>. roles=Admin. mappedRoles=Admin.

Also verify API logs while loading Url Manager:

```powershell
az containerapp logs show -g rg-<your-env-name> -n api --tail 200
```

If API still returns 401, check that the managed identity app-role assignment in step 7 exists and that the API token audience matches API client id (either `<clientId>` or `api://<clientId>`).

You can also run the setup validator script after deployment:

```powershell
cd src
pwsh ./tools/validate-setup.ps1
```

### Common errors

- AADSTS7000218: client assertion or secret is missing.
	- Usually means the app did not send client assertion during code redemption.
	- Verify app configuration uses ClientCredentials with SourceType SignedAssertionFromManagedIdentity.

- AADSTS700213: no matching federated identity record.
	- subject/issuer/audience mismatch in federated credential.
	- Recheck that subject equals managed identity Principal ID exactly.

- Login succeeds but menu items are missing.
	- User is authenticated but has no role claims.
	- Verify app role assignment in Enterprise applications and token optional claims for roles.

- Login/menu works, but Url Manager actions return 401.
	- The admin managed identity is not authorized on the API app registration.
	- Assign API app role(s) to the admin managed identity service principal as described in step 7.

- Login/menu works, API logs show token audience is valid, but calls still return 401.
	- TinyBlazorAdmin may be acquiring downstream tokens from a different identity than the configured user-assigned identity.
	- Verify `AZURE_CLIENT_ID` and `AzureAd__ClientCredentials__0__ManagedIdentityClientId` in the admin container app.
	- Ensure the downstream token handler uses `ManagedIdentityCredential` with that user-assigned client ID.

- Browser shows "An unhandled error has occurred" and network shows `/_blazor?...` returns `404 No Connection with that ID`.
	- This is usually a Blazor Server circuit affinity issue: negotiate happens on one replica, then follow-up request lands on another replica.
	- Ensure ingress sticky sessions are enabled on the admin container app.

```powershell
az resource update --resource-group rg-<your-env-name> --name admin --resource-type Microsoft.App/containerApps --set properties.configuration.ingress.stickySessions.affinity=sticky
```

	- Verify sticky affinity and replica count:

```powershell
az containerapp show -g rg-<your-env-name> -n admin --query "{sticky:properties.configuration.ingress.stickySessions.affinity,maxReplicas:properties.template.scale.maxReplicas}" -o json
az containerapp replica list -g rg-<your-env-name> -n admin -o table
```

	- If a previous failed command accidentally created an env var named `properties.configuration.ingress.stickySessions.affinity`, remove it:

```powershell
az containerapp update -g rg-<your-env-name> -n admin --remove-env-vars properties.configuration.ingress.stickySessions.affinity
```

## How to validate setup configuration

To validate your AzUrlShortener setup configuration, you can run the setup validator script located at `./src/tools/validate-setup.ps1`.

From the `src` directory, run:

```powershell
pwsh ./tools/validate-setup.ps1
```

This script will check your configuration and report any issues with:
- App registrations
- Managed identities
- Federated credentials
- App role assignments
- Container app environment variables
- Token claims configuration

The validator helps ensure all components are properly configured for secure operation.