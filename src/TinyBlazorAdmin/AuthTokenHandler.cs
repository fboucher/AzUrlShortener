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
    // Reuse the credential across requests — DefaultAzureCredential is thread-safe and caches tokens internally
    private static readonly DefaultAzureCredential _credential = new();

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
