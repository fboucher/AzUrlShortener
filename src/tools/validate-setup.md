# validate-setup.ps1

Validates the Entra and managed identity setup used by TinyBlazorAdmin and API.

## What it validates

- App registrations and service principals exist.
- API app roles are present.
- Admin app optional claims include roles.
- Federated credential matches tenant and managed identity principal ID.
- Managed identity has required app-role assignment on API.
- Admin container app includes expected identity wiring and env vars.

## Setup

Open [validate-setup.ps1](./validate-setup.ps1) and fill the CONFIGURATION block placeholders.

Tip: use [setup-admin-auth.ps1](./setup-admin-auth.ps1) first and paste the generated config block.

## Usage

From [src](../):

```powershell
pwsh ./tools/validate-setup.ps1
```

## Output

- Returns exit code `0` when all checks pass.
- Returns exit code `1` when one or more checks fail.
