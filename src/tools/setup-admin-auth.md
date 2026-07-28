# setup-admin-auth.ps1

Automates admin authentication wiring for TinyBlazorAdmin.

## What it configures

- Resolves app registrations for admin and API.
- Resolves user-assigned managed identity details.
- Attaches managed identity to admin container app.
- Sets managed identity related environment variables on admin container app.
- Creates or updates federated credential on the admin app registration.
- Ensures optional claims include roles.
- Assigns API app role to the admin managed identity.
- Prints a configuration block ready for [validate-setup.ps1](./validate-setup.ps1).

## Prerequisites

- Azure CLI installed and signed in.
- Permissions to update Container Apps and Entra app configuration.

## Usage

From [src](../):

```powershell
pwsh ./tools/setup-admin-auth.ps1 -ResourceGroupName <RESOURCE_GROUP_NAME> -ManagedIdentityName <MANAGED_IDENTITY_NAME> -AdminAppDisplayName <ADMIN_APP_DISPLAY_NAME> -ApiAppDisplayName <API_APP_DISPLAY_NAME>
```

Preview only (no writes):

```powershell
pwsh ./tools/setup-admin-auth.ps1 -ResourceGroupName <RESOURCE_GROUP_NAME> -ManagedIdentityName <MANAGED_IDENTITY_NAME> -AdminAppDisplayName <ADMIN_APP_DISPLAY_NAME> -ApiAppDisplayName <API_APP_DISPLAY_NAME> -WhatIf
```

## Common switches

- `-SkipContainerEnvUpdate`: Do not update admin container app env vars.
- `-SkipOptionalClaimsPatch`: Do not patch optional claims on admin app.
- `-SkipApiRoleAssignment`: Do not assign API app role to managed identity.

## Next step

Run [validate-setup.ps1](./validate-setup.ps1).
