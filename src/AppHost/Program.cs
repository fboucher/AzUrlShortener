
using Microsoft.Extensions.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

var customDomain = builder.AddParameter("CustomDomain");
var defaultRedirectUrl = builder.AddParameter("DefaultRedirectUrl");

// To use an existing storage account, you can provide the name and resource group of the existing storage account.
// var existingStorageName = builder.AddParameter("existingStorageName");
// var existingStorageResourceGroup = builder.AddParameter("existingStorageResourceGroup");

var urlStorage = builder.AddAzureStorage("url-data");
					// .AsExisting(existingStorageName, existingStorageResourceGroup);

if (builder.Environment.IsDevelopment())
{
    urlStorage.RunAsEmulator();
}



var strTables = urlStorage.AddTables("strTables");

var azFuncLight = builder.AddAzureFunctionsProject<Projects.Cloud5mins_ShortenerTools_FunctionsLight>("azfunc-light")
							.WithReference(strTables)
							.WaitFor(strTables)
							.WithEnvironment("DefaultRedirectUrl",defaultRedirectUrl)
							.WithExternalHttpEndpoints();

var manAPI = builder.AddProject<Projects.Cloud5mins_ShortenerTools_Api>("api")
						.WithReference(strTables)
						.WaitFor(strTables)
						.WithEnvironment("CustomDomain",customDomain)
						.WithEnvironment("DefaultRedirectUrl",defaultRedirectUrl);
						//.WithExternalHttpEndpoints(); // If you want to access the API directly

builder.AddProject<Projects.Cloud5mins_ShortenerTools_TinyBlazorAdmin>("admin")
		.WithExternalHttpEndpoints()
		.WithReference(manAPI);

builder.Build().Run();
