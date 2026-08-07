using Microsoft.Extensions.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

var customDomain = builder.AddParameter("CustomDomain");
var defaultRedirectUrl = builder.AddParameter("DefaultRedirectUrl");

// To share the same storage as AppHost.Redirect, replace the storage creation below with:
var existingStorageName = builder.AddParameter("existingStorageName");
var existingStorageResourceGroup = builder.AddParameter("existingStorageResourceGroup");

var urlStorage = builder.AddAzureStorage("url-data")
                        .AsExisting(existingStorageName, existingStorageResourceGroup);

var strTables = urlStorage.AddTables("strTables");

var manAPI = builder.AddProject<Projects.Cloud5mins_ShortenerTools_Api>("api")
                        .WithReference(strTables)
                        .WaitFor(strTables)
                        .WithEnvironment("CustomDomain", customDomain)
                        .WithEnvironment("DefaultRedirectUrl", defaultRedirectUrl);

builder.AddProject<Projects.Cloud5mins_ShortenerTools_TinyBlazorAdmin>("admin")
        .WithExternalHttpEndpoints()
        .WithReference(manAPI);

builder.Build().Run();
