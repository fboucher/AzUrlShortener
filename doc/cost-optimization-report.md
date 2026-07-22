# Azure Infrastructure Cost Optimization Report

## 1. Executive Summary

This report evaluates alternative hosting architectures for **AzUrlShortener** to lower monthly Azure execution costs.

The application currently deploys three main services to **Azure Container Apps (ACA)** via .NET Aspire:
* **`FunctionsLight`**: Short URL redirection service (built with `.NET 9` Azure Functions Isolated SDK).
* **`API`**: Core management API (built with `.NET 9` ASP.NET Core Minimal API).
* **`TinyBlazorAdmin`**: Administration dashboard (built with `.NET 9` Blazor Server).

### Key Insight
`FunctionsLight` is **already written as a native Azure Function** using `Microsoft.Azure.Functions.Worker`. It is currently running in a Docker container inside Azure Container Apps only because .NET Aspire containerizes all services during `azd` deployment. 

Moving `FunctionsLight` out of ACA to a native **Azure Functions Consumption Plan (Y1)** instantly reduces its hosting cost to **$0.00/month** (well within Azure's 1 Million free requests/month allowance).

---

## 2. Architecture Alternatives Comparison

Below is the side-by-side analysis of the current baseline and three cost-lowering alternatives.

| Metric / Detail | Current Baseline (ACA) | Option 1: Native Functions + App Service B1 (Recommended) | Option 2: Full Serverless (Functions + App Service B1) | Option 3: Ultra Serverless (Functions + Static Web Apps) |
| :--- | :--- | :--- | :--- | :--- |
| **`FunctionsLight` Host** | Azure Container Apps | **Azure Functions (Y1)** | **Azure Functions (Y1)** | **Azure Functions (Y1)** |
| **`API` Host** | Azure Container Apps | **App Service (Linux B1)** | **Azure Functions (Y1)** | **Azure Functions (Y1)** |
| **`TinyBlazorAdmin` Host** | Azure Container Apps | **App Service (Linux B1)** | **App Service (Linux B1)** | **Static Web Apps (Free)** |
| **Container Registry** | ACR Basic ($5/mo) | **None ($0/mo)** | **None ($0/mo)** | **None ($0/mo)** |
| **Code Impact** | None | **Minimal** (Config / base URL) | **Medium** (API Function conversion) | **High** (Blazor WASM rewrite) |
| **Ease of Deployment** | Moderate (Docker build) | **Very Easy** (Zip / GitHub Actions) | **Easy** (Zip / GitHub Actions) | **Easy** (SWA GitHub Action) |
| **Est. Cost (USD/month)** | **~$22.00 – $35.00** | **~$13.50** | **~$13.50** | **~$0.50** |

---

## 3. Detailed Breakdown of Options

### Current Baseline: All Components on Azure Container Apps (ACA)

* **Where each resource is deployed:**
  * `FunctionsLight`: Container inside ACA Environment (Consumption profile).
  * `API`: Container inside ACA Environment (Internal Ingress).
  * `TinyBlazorAdmin`: Container inside ACA Environment (External Ingress).
  * Supporting: Azure Container Registry (Basic SKU), Log Analytics Workspace, Azure Storage Account.
* **Code Changes Required:** None.
* **Security:** `API` is hidden behind ACA internal VNet ingress (`https+http://api`). `TinyBlazorAdmin` is exposed publicly. Authentication is not currently implemented at the app layer.
* **Estimated Cost (USD/month):** **~$22.00 – $35.00 / mo**
  * ACA Replicas (keeping minReplicas=1 for Blazor SignalR): ~$15.00/mo
  * Azure Container Registry (Basic SKU): ~$5.00/mo
  * Log Analytics Workspace ingestion: ~$2.00 – $5.00/mo
  * Storage Account (Table/Blob): ~$0.50/mo
* **Pros & Cons:**
  * **Pros:** Microservice architecture isolated in a single container environment; unified Aspire telemetry.
  * **Cons:** Highest cost; paying for container registry ($5/mo) and ACA minimum resource allocations.

---

### Option 1: Native Azure Function + App Service B1 (Recommended)

This option deploys `FunctionsLight` to Azure Functions Consumption (Y1) and hosts both `API` and `TinyBlazorAdmin` on a single shared Linux App Service Plan (B1 SKU).

* **Where each resource is deployed:**
  * `FunctionsLight`: Azure Function App (Serverless Consumption Y1 Plan).
  * `API`: Azure App Service (Linux, B1 Plan).
  * `TinyBlazorAdmin`: Azure App Service (Linux, B1 Plan - sharing the *same* plan at no extra charge).
  * Supporting: Azure Storage Account (ACR is eliminated).
* **Code Changes Required:** **Minimal.**
  * `FunctionsLight`: No code changes required. Update Bicep/azd configuration to deploy directly as a Function App host.
  * `API` & `TinyBlazorAdmin`: Update `HttpClient` `BaseAddress` in `TinyBlazorAdmin` (`Program.cs`) from `https+http://api` to the App Service URL or internal host address.
* **Security for `TinyBlazorAdmin` & `API`:**
  * **`TinyBlazorAdmin` Security**: Enable **Microsoft Entra ID (EasyAuth)** directly on the App Service instance with zero code changes.
  * **`API` Security**: Restrict `API` access via App Service **Access Restrictions** (IP whitelisting to allow calls only from `TinyBlazorAdmin`'s outbound IP / VNet) or enable an API Key / EasyAuth header.
* **Ease of Deployment:** **Very Easy.** Eliminates Docker image compilation and ACR image pushing. Uses standard zip deployment via GitHub Actions or `azd`.
* **Estimated Cost (USD/month):** **~$13.50 / mo** *(~50% to 60% savings)*
  * `FunctionsLight` (Consumption Y1): **$0.00** (1M executions/month free).
  * App Service B1 Plan (Linux, hosts both Web Apps): **~$13.00**
  * Container Registry: **$0.00** (Eliminated).
  * Storage Account: **~$0.50**
* **Pros & Cons:**
  * **Pros:** Instant savings, zero container registry fees, excellent support for Blazor Server WebSockets, built-in 1-click Entra ID authentication for admin UI.
  * **Cons:** Minor cold start (<1s) for `FunctionsLight` after idle periods.

---

### Option 2: Full Serverless (Azure Functions Y1 for `FunctionsLight` & `API` + App Service B1 for Admin)

This option converts the Minimal API endpoints in `API` into Azure Functions HTTP triggers, putting both backend services on Azure Functions Consumption plans.

* **Where each resource is deployed:**
  * `FunctionsLight`: Azure Function App (Consumption Y1 Plan).
  * `API`: Azure Function App (Consumption Y1 Plan).
  * `TinyBlazorAdmin`: Azure App Service (Linux B1 Plan).
* **Code Changes Required:** **Medium.**
  * `FunctionsLight`: None.
  * `API`: Refactor Minimal API endpoints in `ShortenerEnpoints.cs` into Azure Functions HTTP triggers (or use `Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore`).
  * `TinyBlazorAdmin`: Update `HttpClient` to append `x-functions-key` header when calling `API`.
* **Security for `TinyBlazorAdmin` & `API`:**
  * **`API` Security**: Secured using native **Azure Function Keys** (`AuthorizationLevel.Function`) or Entra ID EasyAuth.
  * **`TinyBlazorAdmin` Security**: App Service **EasyAuth** (Entra ID).
* **Ease of Deployment:** **Easy.** Standard Function App and App Service zip deployment.
* **Estimated Cost (USD/month):** **~$13.50 / mo**
  * `FunctionsLight`: **$0.00**
  * `API` (Consumption Y1): **$0.00**
  * `TinyBlazorAdmin` (App Service B1): **~$13.00**
  * Storage Account: **~$0.50**
* **Pros & Cons:**
  * **Pros:** Both backend services scale to zero ($0/mo when idle). Simple Function Key security between Admin and API.
  * **Cons:** Code refactoring required for `API`.

---

### Option 3: Maximum Savings / Ultra-Low Cost (~$0.50/mo) — Functions + Static Web Apps (Blazor WASM)

This option converts `TinyBlazorAdmin` from Blazor Server to **Blazor WebAssembly (WASM)**, enabling hosting on **Azure Static Web Apps (Free Tier)**.

* **Where each resource is deployed:**
  * `FunctionsLight`: Azure Function App (Consumption Y1 Plan).
  * `API`: Azure Function App (Consumption Y1 Plan).
  * `TinyBlazorAdmin`: Azure Static Web Apps (Free Tier).
* **Code Changes Required:** **High.**
  * Refactor `TinyBlazorAdmin` from Blazor Server to Blazor WASM.
  * Refactor `API` endpoints into Azure Functions HTTP triggers.
* **Security for `TinyBlazorAdmin` & `API`:**
  * **`TinyBlazorAdmin` Security**: Free built-in Entra ID / GitHub authentication provided out of the box by Azure Static Web Apps.
  * **`API` Security**: Function Keys + CORS restricted to the Static Web App domain.
* **Ease of Deployment:** **Easy.** GitHub Action provided automatically by Azure Static Web Apps.
* **Estimated Cost (USD/month):** **~$0.50 / mo** *(~98% savings)*
  * `FunctionsLight`: **$0.00**
  * `API`: **$0.00**
  * `TinyBlazorAdmin` (SWA Free): **$0.00**
  * Storage Account: **~$0.50**
* **Pros & Cons:**
  * **Pros:** Near-zero operational cost ($0.50/mo), built-in global CDN, free authentication out of the box.
  * **Cons:** Requires significant refactoring of both Blazor Admin and API.

---

## 4. Security Architecture & Configuration Diff (`TinyBlazorAdmin` & `API`)

### 4.1 Security Architecture Comparison Matrix

| Component | ACA Baseline Security | Option 1 (App Service B1 + Functions) | Security Boundary Diff | App Code Impact | Infrastructure (IaC) Diff |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`TinyBlazorAdmin`** | Container Apps Auth Gateway | App Service EasyAuth | **Identical Engine**: Both use Microsoft EasyAuth reverse proxy. Entire web app & WebSockets protected. | **0 Lines** | Change Bicep resource from `authConfigs` to `authsettingsV2`. |
| **`API`** | ACA Internal Ingress (`https+http://api`) | App Service Access Restrictions (IP Whitelist / VNet) | Shifts from internal container environment DNS to App Service URL with IP restriction allowing only `TinyBlazorAdmin` outbound IPs. | **0 Lines** | Add `ipSecurityRestrictions` block in `siteConfig` or use VNet integration. |
| **`FunctionsLight`** | Public ACA Container Ingress | Public Azure Function App (Y1) | **Identical**: Public HTTP trigger for anonymous short URL redirects (`GET /{shortUrl}`). | **0 Lines** | Change Bicep resource from ACA container app to `Microsoft.Web/sites` (`kind: functionapp`). |

---

### 4.2 `TinyBlazorAdmin` Authentication Diff: ACA vs. App Service

Both Azure Container Apps authentication and Azure App Service authentication share the exact same underlying technology: **Azure EasyAuth**.

#### Infrastructure Flow & User Experience Diff:
```
+---------------------------------------------------------------------------------------------------+
| ACA BASELINE:                                                                                     |
| User Browser ---> [ACA Auth Gateway (EasyAuth)] ---> [Container: Kestrel / Blazor Server App]     |
|                                                                                                   |
| OPTION 1 (APP SERVICE):                                                                           |
| User Browser ---> [App Service EasyAuth Proxy]  ---> [App Service: Kestrel / Blazor Server App]   |
+---------------------------------------------------------------------------------------------------+
```

#### Infrastructure (Bicep) Configuration Diff:

**Current ACA Baseline (`authConfigs`):**
```bicep
resource acaAuth 'Microsoft.App/containerApps/authConfigs@2023-05-01' = {
  name: 'current'
  parent: containerAppAdmin
  properties: {
    platform: { enabled: true }
    globalValidation: { unauthenticatedClientAction: 'RedirectToLoginPage' }
    identityProviders: {
      azureActiveDirectory: {
        registration: {
          clientId: adminClientId
          clientSecretSettingName: 'admin-client-secret'
        }
      }
    }
  }
}
```

**Proposed App Service (`authsettingsV2`):**
```bicep
resource appServiceAuth 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'authsettingsV2'
  parent: appServiceAdmin
  properties: {
    platform: { enabled: true }
    globalValidation: { unauthenticatedClientAction: 'RedirectToLoginPage' }
    identityProviders: {
      azureActiveDirectory: {
        registration: {
          clientId: adminClientId
          clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
        }
      }
    }
  }
}
```

#### Code Impact Breakdown:
* **Core App Security**: **0 Lines of Code Changed.** Unauthenticated users cannot view pages or initiate SignalR WebSockets in either architecture.
* **Optional Identity Integration**: If in-app user details (e.g. user email display) are desired, read the `X-MS-CLIENT-PRINCIPAL-NAME` header during the initial HTTP request. This is optional.

---

### 4.3 `API` Isolation & Trust Boundary Diff

* **ACA Baseline Isolation**: `API` is deployed with `ingress: { external: false }`, rendering it accessible **only** within the internal Container Apps environment via `https+http://api`.
* **Option 1 App Service Isolation**: `API` is deployed to Linux App Service. To maintain the trust boundary:
  1. **Access Restrictions (IP Filtering)**: Configure `ipSecurityRestrictions` on `API`'s App Service to accept inbound requests *only* from `TinyBlazorAdmin`'s outbound IP addresses.
  2. **VNet Integration (Optional)**: Connect both App Services to an Azure Virtual Network subnet for private routing.
  3. **App Code Impact**: **0 Lines.** Only update `HttpClient.BaseAddress` in `TinyBlazorAdmin` from `https+http://api` to `https://<api-appservice-name>.azurewebsites.net`.

---

## 5. Final Recommendation & Implementation Roadmap

### **Recommended Option: Option 1 (Native Azure Function + App Service B1)**

### Why Option 1 is Recommended:
1. **Immediate Fulfillment of Goals:** Moves `FunctionsLight` to native Azure Functions Consumption ($0/mo) with zero code modifications needed to the function itself.
2. **Eliminates ACR & Container Overhead:** Saves ~$5/month by removing Azure Container Registry and container management overhead.
3. **Optimized for Blazor Server:** Blazor Server relies on persistent SignalR WebSockets, which run smoothly on App Service B1 without cold starts or session drops.
4. **Best Cost-to-Effort Ratio:** Reduces monthly cost from ~$30/mo down to ~$13.50/mo with minimal code and infrastructure changes.

### Recommended Action Plan:
1. Update `azure.yaml` and infrastructure Bicep templates in `src/infra` to declare `FunctionsLight` as a native Azure Function App (`Microsoft.Web/sites` with `kind: functionapp`).
2. Declare an App Service Plan (Linux B1 SKU) hosting both `TinyBlazorAdmin` and `API`.
3. Configure `TinyBlazorAdmin`'s `HttpClient` `BaseAddress` in appsettings / environment variables to point to `API`'s App Service hostname.
4. Turn on App Service Authentication (EasyAuth with Entra ID) on `TinyBlazorAdmin`.
