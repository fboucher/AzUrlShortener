using Microsoft.Identity.Web;
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

builder.AddAzureTableClient("strTables");

builder.Services.AddTransient<ILogger>(sp =>
{
    var loggerFactory = sp.GetRequiredService<ILoggerFactory>();
    return loggerFactory.CreateLogger("shortenerLogger");
});

// Add Microsoft Entra ID JWT Bearer authentication
builder.Services.AddMicrosoftIdentityWebApiAuthentication(builder.Configuration);
builder.Services.Configure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, options =>
{
    var apiClientId = builder.Configuration["AzureAd:ClientId"];
    if (!string.IsNullOrWhiteSpace(apiClientId))
    {
        // Managed identity app tokens can use either audience format depending on issuer settings.
        options.TokenValidationParameters.ValidAudiences =
        [
            apiClientId,
            $"api://{apiClientId}"
        ];
    }
});

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("UrlCreatorOrAbove", policy =>
        policy.RequireRole("UrlCreator", "UrlManager", "Admin"));
    options.AddPolicy("UrlManagerOrAbove", policy =>
        policy.RequireRole("UrlManager", "Admin"));
    options.AddPolicy("AdminOnly", policy =>
        policy.RequireRole("Admin"));
});

var app = builder.Build();

app.MapDefaultEndpoints();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapShortenerEnpoints();

app.Run();

