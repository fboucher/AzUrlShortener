# azd Deploy Troubleshooting Guide

> **Environment:** AzUrlShortener · .NET 10 · .NET Aspire 13.1.0 · azd 1.27.1 · Visual Studio 2026

---

## Table of Contents

1. [Error: `empty dotnet configuration output`](#1-error-empty-dotnet-configuration-output)
2. [Error: `EnableSdkContainerSupport` suggestion (misleading)](#2-error-enablesdkcontainersupport-suggestion-misleading)
3. [Error: `InvalidResourceLocation` — location conflict on re-deploy](#3-error-invalidresourcelocation--location-conflict-on-re-deploy)
4. [Error: `AZURE_LOCATION` prompt overwrites correct location](#4-error-azure_location-prompt-overwrites-correct-location)
5. [Environment Reference](#5-environment-reference)

---

## 1. Error: `empty dotnet configuration output`

### Symptom

```
ERROR: empty dotnet configuration output

Suggestion: Ensure project '...\FunctionsLight.csproj' is enabled for container
support and try again. To enable SDK container support, set the
'EnableSdkContainerSupport' property to true in your project file
```

All three services fail (`admin`, `api`, `azfunc-light`) with the same error.

### Root Cause

**The `.NET 10.0.400-preview` SDK** (installed by Visual Studio 2026) changed the
behaviour of `--getProperty` when combined with `--artifacts-path`. When both flags
are used together, the property value is **no longer written to stdout** — it goes to a
file in the artifacts directory instead. `azd` reads from stdout and receives an empty
string.

`azd` internally calls:

```
dotnet publish <project> -r linux-x64 -c Release /t:PublishContainer
  --getProperty:GeneratedContainerConfiguration
  -p:ContainerEngine=<engine>
  --artifacts-path <temp-dir>
```

The `--artifacts-path` flag is always added by `azd`. With SDK `10.0.400-preview`,
the `GeneratedContainerConfiguration` JSON never reaches stdout, so `azd` errors out.

### Why `api` sometimes passes but `admin` / `azfunc-light` fail

`azd` only calls `--getProperty:GeneratedContainerConfiguration` for services that
expose **external HTTP endpoints**. In `AppHost/Program.cs`:

| Service | `.WithExternalHttpEndpoints()` | `azd` calls `--getProperty` |
|---|---|---|
| `api` | ✗ (commented out) | ✗ — skips check |
| `admin` | ✓ | ✓ — fails |
| `azfunc-light` | ✓ | ✓ — fails |

### Fix — Pin to stable .NET SDK

Two `global.json` files are required because `azd` runs `dotnet publish` from a
**temp directory** (`%LOCALAPPDATA%\Temp\azd-*`), not from the repository root.
Walking up from that temp path must still reach a `global.json`.

#### 1. Repo root — `global.json`

```json
{
  "sdk": {
	"version": "10.0.301",
	"rollForward": "latestPatch"
  }
}
```

Covers builds run from within the repository tree.

#### 2. User home — `%USERPROFILE%\global.json`

```json
{
  "sdk": {
	"version": "10.0.301",
	"rollForward": "latestPatch"
  }
}
```

Covers `azd`'s subprocess launched from the system temp directory.

> **Verify both are effective:**
> ```powershell
> # From repo root
> cd C:\...\AzUrlShortener; dotnet --version   # must print 10.0.301
>
> # From TEMP (simulates azd subprocess CWD)
> cd $env:TEMP; dotnet --version               # must print 10.0.301
> ```

### Installed SDKs (reference)

```
9.0.315   [C:\Program Files\dotnet\sdk]
10.0.301  [C:\Program Files\dotnet\sdk]   ← target (stable)
10.0.400-preview.0.26312.103              ← installed by VS 2026, causes the bug
```

---

## 2. Error: `EnableSdkContainerSupport` suggestion (misleading)

### Symptom

`azd`'s suggestion to add `<EnableSdkContainerSupport>true</EnableSdkContainerSupport>`
appears even when the property **is already set**.

### Root Cause

This is a **generic hint** that `azd` always appends to `empty dotnet configuration
output` errors. It is **not the actual cause**. Adding the property has no effect on
the underlying SDK version bug.

### What NOT to do

Do **not** add `EnableSdkContainerSupport` to `Api.csproj` or
`TinyBlazorAdmin.csproj`. The old working deployment did not have this property in
any project (except `FunctionsLight.csproj` where it can be left for clarity).

### Current project state (correct)

```xml
<!-- FunctionsLight.csproj — EnableSdkContainerSupport present (optional but harmless) -->
<EnableSdkContainerSupport>true</EnableSdkContainerSupport>

<!-- Api.csproj and TinyBlazorAdmin.csproj — property absent (correct) -->
```

---

## 3. Error: `InvalidResourceLocation` — location conflict on re-deploy

### Symptom

```
ERROR: deployment failed: step "provision" failed: ...

InvalidResourceLocation: The resource 'cae-fdkpaja47irka' already exists in
location 'northeurope' in resource group 'rg-myAzUrlShortener'. A resource with
the same name cannot be created in location 'westeurope'.
```

### Root Cause

The `AZURE_LOCATION` environment variable in `.azure/myAzUrlShortener/.env` was set
to `westeurope` while the existing Azure resources are in `northeurope`.

This commonly happens when:
- The azd environment was re-initialised without preserving the location.
- `azd up` prompted for location and the wrong region was chosen interactively.

### Fix

```powershell
azd env set AZURE_LOCATION northeurope
```

Then also persist it in `config.json` (see Section 4) to avoid future prompts.

---

## 4. Error: `AZURE_LOCATION` prompt overwrites correct location

### Symptom

`azd up` always interactively prompts:

```
? Enter a value for the 'location' infrastructure parameter::
```

Choosing incorrectly (e.g. `westeurope`) overwrites the saved location and triggers
the `InvalidResourceLocation` error on every subsequent run.

### Root Cause

`azd up` prompts for any Bicep parameter **not saved** in
`.azure/<env>/config.json`. The `location` parameter was missing, so `azd` asked
every time.

### Fix

Add `location` to `.azure/myAzUrlShortener/config.json`:

```json
{
  "infra": {
	"parameters": {
	  "CustomDomain": "https://go.sonnes.cloud",
	  "DefaultRedirectUrl": "https://blog.sonnes.cloud",
	  "location": "northeurope"
	}
  }
}
```

> `config.json` feeds directly into `main.parameters.json`, which maps
> `location → ${AZURE_LOCATION}`. Both files must agree on `northeurope`.

---

## 5. Environment Reference

### Azure resources

| Resource | Type | Location |
|---|---|---|
| `rg-myAzUrlShortener` | Resource Group | `northeurope` |
| `cae-fdkpaja47irka` | Container Apps Environment | `northeurope` |
| `acrfdkpaja47irka` | Container Registry | `northeurope` |
| `mi-fdkpaja47irka` | Managed Identity | `northeurope` |
| `law-fdkpaja47irka` | Log Analytics Workspace | `northeurope` |
| `urldatafdkpaja47irka` | Storage (URL data / Tables) | `northeurope` |
| `funcstoragea17cafdkpaja4` | Storage (Functions) | `northeurope` |

### azd environment values

| Key | Value |
|---|---|
| `AZURE_ENV_NAME` | `myAzUrlShortener` |
| `AZURE_LOCATION` | `northeurope` |
| `AZURE_RESOURCE_GROUP` | `rg-myAzUrlShortener` |
| `AZURE_CONTAINER_REGISTRY_ENDPOINT` | `acrfdkpaja47irka.azurecr.io` |

### Tool versions (working combination)

| Tool | Version |
|---|---|
| `azd` | 1.27.1 |
| .NET SDK | **10.0.301** (stable — do NOT let 10.0.400-preview take over) |
| .NET Aspire AppHost SDK | 13.1.0 |
| Visual Studio | 2026 (18.7.2) |

### Key files

| File | Purpose |
|---|---|
| `global.json` *(repo root)* | Pins SDK to 10.0.301 for local builds |
| `%USERPROFILE%\global.json` | Pins SDK to 10.0.301 for azd temp-dir subprocesses |
| `.azure/myAzUrlShortener/.env` | azd environment variables incl. `AZURE_LOCATION` |
| `.azure/myAzUrlShortener/config.json` | Persisted Bicep parameter answers (incl. `location`) |
| `src/infra/main.parameters.json` | Maps Bicep params to `${AZURE_*}` env vars |
| `src/AppHost/Program.cs` | Controls which services get external HTTP endpoints |

---

## Quick-fix Checklist

Before running `azd deploy` or `azd up`, verify:

- [ ] `cd $env:REPO; dotnet --version` → `10.0.301`
- [ ] `cd $env:TEMP; dotnet --version` → `10.0.301`
- [ ] `azd env get-values | Select-String LOCATION` → `northeurope`
- [ ] `.azure/myAzUrlShortener/config.json` contains `"location": "northeurope"`
- [ ] Docker Desktop is running (required for container image builds)
