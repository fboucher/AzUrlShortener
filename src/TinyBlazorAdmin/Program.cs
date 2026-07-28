using Microsoft.FluentUI.AspNetCore.Components;
using Cloud5mins.ShortenerTools.TinyBlazorAdmin.Components;
using Cloud5mins.ShortenerTools.TinyBlazorAdmin;
using System.Security.Claims;
using Azure.Core;
using Azure.Identity;
using Microsoft.FluentUI.AspNetCore.Components.Components.Tooltip;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.UI;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

var azureAd = builder.Configuration.GetSection("AzureAd");
var managedIdentityClientId = builder.Configuration["AzureAd:ClientCredentials:0:ManagedIdentityClientId"]
                              ?? builder.Configuration["AZURE_CLIENT_ID"];

TokenCredential assertionCredential = !string.IsNullOrWhiteSpace(managedIdentityClientId)
    ? new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(managedIdentityClientId))
    : new DefaultAzureCredential();

var tokenExchangeRequestContext = new TokenRequestContext(["api://AzureADTokenExchange/.default"]);

builder.Services
    .AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApp(azureAd);

builder.Services.AddCascadingAuthenticationState();

builder.Services.Configure<CookieAuthenticationOptions>(CookieAuthenticationDefaults.AuthenticationScheme, cookieOptions =>
{
    cookieOptions.AccessDeniedPath = "/access-denied";
});

builder.Services.Configure<OpenIdConnectOptions>(OpenIdConnectDefaults.AuthenticationScheme, options =>
{
    // Keep incoming claim names from Entra (for example: "roles", "name")
    // so role-based authorization matches app role values directly.
    options.MapInboundClaims = false;

    options.ResponseType = OpenIdConnectResponseType.Code;
    options.ResponseMode = "form_post";
    options.UsePkce = true;
    options.SaveTokens = false;

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");

    options.TokenValidationParameters.RoleClaimType = ClaimTypes.Role;
    options.TokenValidationParameters.NameClaimType = "name";

    options.Events.OnRemoteFailure = context =>
    {
        var error = context.Failure?.Message ?? "Unknown authentication error";
        context.HandleResponse();
        context.Response.Redirect($"/access-denied?reason={Uri.EscapeDataString(error)}");
        return Task.CompletedTask;
    };

    options.Events.OnAuthenticationFailed = context =>
    {
        var error = context.Exception?.Message ?? "Authentication failed";
        context.HandleResponse();
        context.Response.Redirect($"/access-denied?reason={Uri.EscapeDataString(error)}");
        return Task.CompletedTask;
    };

    options.Events.OnAuthorizationCodeReceived = async context =>
    {
        var assertion = await assertionCredential.GetTokenAsync(tokenExchangeRequestContext, context.HttpContext.RequestAborted);

        if (context.TokenEndpointRequest is not null)
        {
            context.TokenEndpointRequest.ClientAssertionType =
                "urn:ietf:params:oauth:client-assertion-type:jwt-bearer";
            context.TokenEndpointRequest.ClientAssertion = assertion.Token;
        }
    };

    options.Events.OnTokenValidated = context =>
    {
        if (context.Principal?.Identity is ClaimsIdentity identity)
        {
            var roleClaims = context.Principal.Claims.Where(c => c.Type == "roles").Select(c => c.Value).ToArray();
            var mappedRoleClaims = context.Principal.Claims.Where(c => c.Type == ClaimTypes.Role).Select(c => c.Value).ToArray();

            // Normalize Entra role claims so authorization works regardless of claim mapping behavior.
            if (mappedRoleClaims.Length == 0 && roleClaims.Length > 0)
            {
                foreach (var role in roleClaims)
                {
                    identity.AddClaim(new Claim(ClaimTypes.Role, role));
                }
            }

            if (roleClaims.Length == 0 && mappedRoleClaims.Length > 0)
            {
                foreach (var role in mappedRoleClaims)
                {
                    identity.AddClaim(new Claim("roles", role));
                }
            }
        }

        var logger = context.HttpContext.RequestServices
            .GetRequiredService<ILoggerFactory>()
            .CreateLogger("Auth");

        var userName = context.Principal?.Identity?.Name ?? "(unknown)";
        var roles = context.Principal?.Claims
            .Where(c => c.Type == "roles")
            .Select(c => c.Value)
            .ToArray() ?? [];

        var mappedRoles = context.Principal?.Claims
            .Where(c => c.Type == ClaimTypes.Role)
            .Select(c => c.Value)
            .ToArray() ?? [];

        var claimTypes = context.Principal?.Claims
            .Select(c => c.Type)
            .Distinct(StringComparer.Ordinal)
            .OrderBy(t => t)
            .ToArray() ?? [];

        logger.LogInformation(
            "Token validated for {User}. roles={Roles}. mappedRoles={MappedRoles}. claimTypes={ClaimTypes}",
            userName,
            string.Join(",", roles),
            string.Join(",", mappedRoles),
            string.Join("|", claimTypes));
        return Task.CompletedTask;
    };
});

// Isolate Data Protection keys to this app so they are not shared across apps.
builder.Services.AddDataProtection()
    .SetApplicationName("AzUrlShortener-TinyBlazorAdmin");

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("UrlCreatorOrAbove", policy =>
        policy.RequireRole("UrlCreator", "UrlManager", "Admin"));
    options.AddPolicy("UrlManagerOrAbove", policy =>
        policy.RequireRole("UrlManager", "Admin"));
    options.AddPolicy("AdminOnly", policy =>
        policy.RequireRole("Admin"));
});

builder.Services.AddHttpContextAccessor();

builder.Services.AddHttpClient<UrlManagerClient>(client =>
            {
                client.BaseAddress = new Uri("https+http://api");
            })
    .AddHttpMessageHandler<AuthTokenHandler>();

builder.Services.AddTransient<AuthTokenHandler>();

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();
builder.Services.AddControllersWithViews()
    .AddMicrosoftIdentityUI();
builder.Services.AddFluentUIComponents();
builder.Services.AddScoped<ITooltipService, TooltipService>();

builder.Services.AddBlazorBootstrap();

var app = builder.Build();
app.MapDefaultEndpoints();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();
app.UseAntiforgery();

app.MapControllers();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
