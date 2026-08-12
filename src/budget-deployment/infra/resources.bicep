@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Custom domain passed to API service')
param CustomDomain string

@description('Default redirect URL passed to API and function services')
param DefaultRedirectUrl string

@description('Table service endpoint of the url-data storage account (for URL shortener data)')
param urlDataTableEndpoint string

@description('Blob service endpoint of the func storage account (AzureWebJobsStorage)')
param funcStorageBlobEndpoint string

@description('Queue service endpoint of the func storage account (AzureWebJobsStorage)')
param funcStorageQueueEndpoint string

@description('Table service endpoint of the func storage account (AzureWebJobsStorage)')
param funcStorageTableEndpoint string

var resourceToken = uniqueString(resourceGroup().id)

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-${resourceToken}'
  location: location
  tags: tags
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-${resourceToken}'
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    family: 'B'
    capacity: 1
  }
  // Linux is required for App Service sidecar containers
  kind: 'linux'
  properties: {
    reserved: true
  }
  tags: union(tags, {
    'aspire-resource-name': 'budget-appservice-plan'
  })
}

// Container registry to host the API sidecar image
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acr${resourceToken}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
  tags: tags
}

// Allow the managed identity to pull images from ACR
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // AcrPull built-in role: 7f951dda-4ed3-4680-a7ca-43fe172d538d
  name: guid(containerRegistry.id, managedIdentity.id, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: containerRegistry
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalType: 'ServicePrincipal'
  }
}

resource functionConsumptionPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-func-${resourceToken}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  kind: 'functionapp'
  properties: {
    reserved: false
  }
  tags: union(tags, {
    'aspire-resource-name': 'budget-functions-plan'
  })
}

resource functionSite 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-${resourceToken}'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: functionConsumptionPlan.id
    httpsOnly: true
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: managedIdentity.properties.clientId
        }
        {
          name: 'DefaultRedirectUrl'
          value: DefaultRedirectUrl
        }
        // AzureWebJobsStorage uses identity-based access (no connection string)
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: funcStorageBlobEndpoint
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: funcStorageQueueEndpoint
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: funcStorageTableEndpoint
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: managedIdentity.properties.clientId
        }
        // strTables connection used by AddAzureTableClient("strTables")
        {
          name: 'ConnectionStrings__strTables'
          value: urlDataTableEndpoint
        }
      ]
    }
  }
  tags: union(tags, {
    'azd-service-name': 'azfunc-light'
    'aspire-resource-name': 'azfunc-light'
  })
}

// apiSite removed – the API is now deployed as a sidecar container on adminSite.
// See the apiSidecar sitecontainer resource below.

// Admin site – Linux code-based app (main container receives all external traffic).
// The API runs as a sidecar container on the same site unit and is only
// reachable via localhost:8080 (never from the internet).
resource adminSite 'Microsoft.Web/sites@2023-12-01' = {
  name: 'admin-${resourceToken}'
  location: location
  kind: 'app,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        // ── Admin settings ──────────────────────────────────────────────────
        {
          name: 'AZURE_CLIENT_ID'
          value: managedIdentity.properties.clientId
        }
        // Aspire service-discovery: route API calls to the sidecar on localhost.
        // The HTTPS key is intentionally omitted so the client uses plain HTTP
        // for localhost-to-localhost communication.
        {
          name: 'services__api__http__0'
          value: 'http://localhost:8080'
        }
        // ── API settings (inherited by the sidecar via
        //    inheritAppSettingsAndConnectionStrings: true) ──────────────────
        {
          name: 'CustomDomain'
          value: CustomDomain
        }
        {
          name: 'DefaultRedirectUrl'
          value: DefaultRedirectUrl
        }
        // strTables connection used by AddAzureTableClient("strTables")
        {
          name: 'ConnectionStrings__strTables'
          value: urlDataTableEndpoint
        }
      ]
    }
  }
  tags: union(tags, {
    'azd-service-name': 'admin'
    'aspire-resource-name': 'admin'
  })
}

// API sidecar container – shares the same network namespace as adminSite.
// App Service only routes inbound internet traffic to the main (admin) container;
// this container is exclusively reachable via http://localhost:8080 from within
// the site unit.
resource apiSidecar 'Microsoft.Web/sites/sitecontainers@2024-04-01' = {
  parent: adminSite
  name: 'api'
  properties: {
    // Image is pushed to ACR by the postprovision hook.
    // 'latest' is refreshed by restarting the site after each push.
    image: '${containerRegistry.properties.loginServer}/api:latest'
    isMain: false
    targetPort: '8080'
    // Pull image using the site's user-assigned managed identity
    authType: 'UserAssigned'
    userManagedIdentityClientId: managedIdentity.properties.clientId
    // All app settings on adminSite are inherited by the sidecar as env vars.
    // This gives the API its AZURE_CLIENT_ID, CustomDomain, DefaultRedirectUrl,
    // and ConnectionStrings__strTables without duplicating them.
    inheritAppSettingsAndConnectionStrings: true
  }
  dependsOn: [
    acrPullRole
  ]
}

resource principalRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(resourceGroup().id, principalId, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c'))
  scope: resourceGroup()
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  }
}

output MANAGED_IDENTITY_CLIENT_ID string = managedIdentity.properties.clientId
output MANAGED_IDENTITY_NAME string = managedIdentity.name
output MANAGED_IDENTITY_PRINCIPAL_ID string = managedIdentity.properties.principalId
output AZURE_APP_SERVICE_PLAN_NAME string = appServicePlan.name
output AZURE_FUNCTION_APP_NAME string = functionSite.name
output AZURE_ADMIN_APP_NAME string = adminSite.name
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
