using Microsoft.Extensions.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

var defaultRedirectUrl = builder.AddParameter("DefaultRedirectUrl");

var urlStorage = builder.AddAzureStorage("url-data");

if (builder.Environment.IsDevelopment())
{
    urlStorage.RunAsEmulator();
}

var strTables = urlStorage.AddTables("strTables");

var azFuncLight = builder.AddAzureFunctionsProject<Projects.Cloud5mins_ShortenerTools_FunctionsLight>("azfunc-light")
                            .WithReference(strTables)
                            .WaitFor(strTables)
                            .WithEnvironment("DefaultRedirectUrl", defaultRedirectUrl)
                            .WithExternalHttpEndpoints();

builder.Build().Run();
