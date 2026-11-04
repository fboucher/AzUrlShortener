using Microsoft.FluentUI.AspNetCore.Components;
using Cloud5mins.ShortenerTools.TinyBlazorAdmin.Components;
using Cloud5mins.ShortenerTools.TinyBlazorAdmin;
using Microsoft.FluentUI.AspNetCore.Components.Components.Tooltip;
using Cloud5mins.ShortenerTools.TinyBlazorAdmin.News;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

builder.Services.AddHttpClient<UrlManagerClient>(client => 
            {
                client.BaseAddress = new Uri("https+http://api");
            });

// News section on the home page (see doc/news.md)
builder.Services.Configure<NewsOptions>(builder.Configuration.GetSection(NewsOptions.SectionName));
builder.Services.AddMemoryCache();
builder.Services.AddHttpClient<INewsService, NewsService>(client =>
            {
                client.Timeout = TimeSpan.FromSeconds(10);
            });

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();
builder.Services.AddFluentUIComponents();
builder.Services.AddScoped<ITooltipService, TooltipService>();

//Blazor Bootstrap service
builder.Services.AddBlazorBootstrap();

var app = builder.Build();
app.MapDefaultEndpoints();


// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles();
app.UseAntiforgery();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
