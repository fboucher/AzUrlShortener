using System.Reflection;
using Cloud5mins.ShortenerTools.TinyBlazorAdmin;
using Microsoft.Extensions.Configuration;

namespace Cloud5mins.ShortenerTools.TinyBlazorAdmin.Tests;

public class ApplicationVersionTests
{
    [Fact]
    public void Resolve_UsesConfiguredVersionWhenAvailable()
    {
        var configuration = CreateConfiguration("  registry.example/admin:v4.1.2  ");

        var version = ApplicationVersion.Resolve(configuration, typeof(ApplicationVersion).Assembly);

        Assert.Equal("registry.example/admin:v4.1.2", version);
    }

    [Theory]
    [InlineData("")]
    [InlineData("  ")]
    public void Resolve_UsesAssemblyInformationalVersionWhenNotConfigured(string configuredVersion)
    {
        var configuration = CreateConfiguration(configuredVersion);
        var assembly = typeof(ApplicationVersion).Assembly;
        var expectedVersion = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;

        var version = ApplicationVersion.Resolve(configuration, assembly);

        Assert.Equal(expectedVersion, version);
    }

    private static IConfiguration CreateConfiguration(string configuredVersion) =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APP_VERSION"] = configuredVersion
            })
            .Build();
}
