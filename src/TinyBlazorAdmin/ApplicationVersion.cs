using System.Reflection;
using Microsoft.Extensions.Configuration;

namespace Cloud5mins.ShortenerTools.TinyBlazorAdmin;

internal static class ApplicationVersion
{
    internal static string Resolve(IConfiguration configuration, Assembly assembly)
    {
        var configuredVersion = configuration["APP_VERSION"];
        if (!string.IsNullOrWhiteSpace(configuredVersion))
        {
            return configuredVersion.Trim();
        }

        var informationalVersion = assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion;
        if (!string.IsNullOrWhiteSpace(informationalVersion))
        {
            return informationalVersion;
        }

        return assembly.GetName().Version?.ToString()
            ?? throw new InvalidOperationException("The application assembly has no version metadata.");
    }
}
