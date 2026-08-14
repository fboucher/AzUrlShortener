targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention, the name of the resource group for your application will use this name, prefixed with rg-')
param environmentName string

@minLength(1)
@description('The location used for all deployed resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

param CustomDomain string
param DefaultRedirectUrl string

var tags = {
  'azd-env-name': environmentName
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources './resources.bicep' = {
  scope: rg
  name: 'resources'
  params: {
    location: location
    tags: tags
    principalId: principalId
    CustomDomain: CustomDomain
    DefaultRedirectUrl: DefaultRedirectUrl
    urlDataTableEndpoint: url_data.outputs.tableEndpoint
    funcStorageBlobEndpoint: funcstoragea17ca.outputs.blobEndpoint
    funcStorageQueueEndpoint: funcstoragea17ca.outputs.queueEndpoint
    funcStorageTableEndpoint: funcstoragea17ca.outputs.tableEndpoint
  }
}

module funcstoragea17ca './funcstoragea17ca/funcstoragea17ca.module.bicep' = {
  name: 'funcstoragea17ca'
  scope: rg
  params: {
    location: location
  }
}

module funcstoragea17ca_roles './funcstoragea17ca-roles/funcstoragea17ca-roles.module.bicep' = {
  name: 'funcstoragea17ca-roles'
  scope: rg
  params: {
    funcstoragea17ca_outputs_name: funcstoragea17ca.outputs.name
    location: location
    principalId: resources.outputs.MANAGED_IDENTITY_PRINCIPAL_ID
    principalType: 'ServicePrincipal'
  }
}

module url_data './url-data/url-data.module.bicep' = {
  name: 'url-data'
  scope: rg
  params: {
    location: location
  }
}

module url_data_roles './url-data-roles/url-data-roles.module.bicep' = {
  name: 'url-data-roles'
  scope: rg
  params: {
    location: location
    principalId: resources.outputs.MANAGED_IDENTITY_PRINCIPAL_ID
    principalType: 'ServicePrincipal'
    url_data_outputs_name: url_data.outputs.name
  }
}

output MANAGED_IDENTITY_CLIENT_ID string = resources.outputs.MANAGED_IDENTITY_CLIENT_ID
output MANAGED_IDENTITY_NAME string = resources.outputs.MANAGED_IDENTITY_NAME
output AZURE_APP_SERVICE_PLAN_NAME string = resources.outputs.AZURE_APP_SERVICE_PLAN_NAME
output AZURE_FUNCTION_APP_NAME string = resources.outputs.AZURE_FUNCTION_APP_NAME
output AZURE_ADMIN_APP_NAME string = resources.outputs.AZURE_ADMIN_APP_NAME
output AZURE_CONTAINER_REGISTRY_NAME string = resources.outputs.AZURE_CONTAINER_REGISTRY_NAME
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output FUNCSTORAGEA17CA_BLOBENDPOINT string = funcstoragea17ca.outputs.blobEndpoint
output FUNCSTORAGEA17CA_DATALAKEENDPOINT string = funcstoragea17ca.outputs.dataLakeEndpoint
output FUNCSTORAGEA17CA_QUEUEENDPOINT string = funcstoragea17ca.outputs.queueEndpoint
output FUNCSTORAGEA17CA_TABLEENDPOINT string = funcstoragea17ca.outputs.tableEndpoint
output URL_DATA_TABLEENDPOINT string = url_data.outputs.tableEndpoint
