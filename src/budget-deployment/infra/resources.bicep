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
  kind: 'app'
  properties: {
    reserved: false
  }
  tags: union(tags, {
    'aspire-resource-name': 'budget-appservice-plan'
  })
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

resource apiSite 'Microsoft.Web/sites@2023-12-01' = {
  name: 'api-${resourceToken}'
  location: location
  kind: 'app'
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
        {
          name: 'AZURE_CLIENT_ID'
          value: managedIdentity.properties.clientId
        }
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
    'azd-service-name': 'api'
    'aspire-resource-name': 'api'
  })
}

resource adminSite 'Microsoft.Web/sites@2023-12-01' = {
  name: 'admin-${resourceToken}'
  location: location
  kind: 'app'
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
        {
          name: 'AZURE_CLIENT_ID'
          value: managedIdentity.properties.clientId
        }
        {
          name: 'API_HTTP'
          value: 'https://${apiSite.properties.defaultHostName}'
        }
        {
          name: 'API_HTTPS'
          value: 'https://${apiSite.properties.defaultHostName}'
        }
        {
          name: 'services__api__http__0'
          value: 'https://${apiSite.properties.defaultHostName}'
        }
        {
          name: 'services__api__https__0'
          value: 'https://${apiSite.properties.defaultHostName}'
        }
      ]
    }
  }
  tags: union(tags, {
    'azd-service-name': 'admin'
    'aspire-resource-name': 'admin'
  })
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
output AZURE_API_APP_NAME string = apiSite.name
output AZURE_ADMIN_APP_NAME string = adminSite.name
