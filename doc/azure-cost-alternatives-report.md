## Team Report — Azure cost-lowering alternatives

**Recommendation:** Move **`FunctionLight` to Azure Functions Consumption now**, keep **`TinyBlazorAdmin` + `API` on ACA** initially, then evaluate moving `TinyBlazorAdmin` + `API` to App Service in phase 2. This gives immediate savings with lower code risk and avoids weakening API security.

**Assumptions for cost:** East US, low-to-medium traffic, current monitoring/storage patterns, no premium networking.

| Option | Where each resource is deployed | Code change required | Est. cost (USD/month) | Pros | Cons |
|---|---|---|---:|---|---|
| **Current baseline** | TinyBlazorAdmin: ACA, API: ACA, FunctionLight: ACA, ACR+Log Analytics+Storage | None | **$20–$85** | Current behavior unchanged | Higher idle/container overhead |
| **Recommended (phase 1): ACA + Functions hybrid** | TinyBlazorAdmin: ACA, API: ACA, FunctionLight: **Azure Functions (Consumption)**, Storage unchanged, Log Analytics reduced | **Moderate** (infra/config split; Function App settings; AppHost/deploy wiring updates) | **$15–$50** | Good savings, low migration risk, keeps current API trust boundary | Still pays some ACA overhead |
| **Phase 2 candidate: App Service + Functions** | TinyBlazorAdmin: App Service, API: App Service, FunctionLight: Azure Functions, App Insights/Storage | **Moderate** (service discovery/base URL, auth model, infra/pipeline updates) | **$25–$60** | Simpler ops model, predictable hosting | Can cost more than hybrid at low traffic; auth/network must be re-hardened |
| **Aggressive serverless-first** | TinyBlazorAdmin: Static hosting/SWA, API: Azure Functions HTTP, FunctionLight: Azure Functions | **Significant** (Blazor Interactive Server refactor + API refactor) | **$8–$30** | Lowest potential cost | Highest code impact and security redesign effort |

### Security impact summary (`TinyBlazorAdmin` + `API`)
- **Key risk:** API currently relies heavily on platform/network controls; moving API to public HTTP endpoints without explicit app auth increases risk.
- **Required controls for any lower-cost option:** Entra/JWT auth on API, private ingress where possible, Managed Identity + RBAC, Key Vault-backed secrets, HTTPS-only, monitoring/alerts.

### Why this recommendation
- Aligns with your direction that **`FunctionLight` should be an Azure Function**.
- Delivers meaningful savings now with less disruption.
- Preserves a safer migration path for `TinyBlazorAdmin` and `API` before any larger architecture rewrite.
