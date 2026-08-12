# Build stage – uses the full SDK image
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy NuGet central version management before restore
COPY ["Directory.Packages.props", "./"]

# Copy project files and restore (layer-cache friendly)
COPY ["Api/Cloud5mins.ShortenerTools.Api.csproj", "Api/"]
COPY ["Core/Cloud5mins.ShortenerTools.Core.csproj", "Core/"]
COPY ["ServiceDefaults/Cloud5mins.ShortenerTools.ServiceDefaults.csproj", "ServiceDefaults/"]
RUN dotnet restore "Api/Cloud5mins.ShortenerTools.Api.csproj"

# Copy everything and publish
COPY . .
RUN dotnet publish "Api/Cloud5mins.ShortenerTools.Api.csproj" \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false

# Runtime stage – lightweight ASP.NET image
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

# Listen on HTTP only; App Service routes external traffic to the admin container.
# UseHttpsRedirection is a no-op when no HTTPS port is configured.
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Cloud5mins.ShortenerTools.Api.dll"]
