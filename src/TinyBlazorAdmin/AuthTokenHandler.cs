using Azure.Core;
using Azure.Identity;
using System.Net.Http.Headers;

namespace Cloud5mins.ShortenerTools.TinyBlazorAdmin;

/// <summary>
/// Delegating handler that acquires a Managed Identity (or DefaultAzureCredential for local dev)
/// access token for the downstream API and attaches it as a Bearer token to every outgoing request.
/// This is an app-to-app token — no OBO flow needed. User RBAC is enforced in the Blazor UI.
/// </summary>
public class AuthTokenHandler(IConfiguration configuration) : DelegatingHandler
{
    // Use the configured user-assigned managed identity in Azure; fall back to local default credentials for dev.
    private readonly TokenCredential _credential =
        !string.IsNullOrWhiteSpace(configuration["AzureAd:ClientCredentials:0:ManagedIdentityClientId"]
            ?? configuration["AZURE_CLIENT_ID"])
            ? new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(
                configuration["AzureAd:ClientCredentials:0:ManagedIdentityClientId"]
                ?? configuration["AZURE_CLIENT_ID"]!))
            : new DefaultAzureCredential();

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var apiClientId = configuration["AzureAd:DownstreamApi:ApiClientId"]
                          ?? configuration["AzureAd:DownstreamApi:Scopes"]?
                                .Split(' ').FirstOrDefault()?
                                .Replace("/.default", "")
                                .Replace("api://", "");

        if (!string.IsNullOrEmpty(apiClientId))
        {
            var scope = apiClientId.StartsWith("api://")
                ? $"{apiClientId}/.default"
                : $"api://{apiClientId}/.default";

            var tokenContext = new TokenRequestContext([scope]);
            var tokenResult = await _credential.GetTokenAsync(tokenContext, cancellationToken);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", tokenResult.Token);
        }

        return await base.SendAsync(request, cancellationToken);
    }
}
