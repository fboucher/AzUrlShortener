@description('The location for the resource(s) to be deployed.')
param location string = resourceGroup().location

resource funcstoragea17ca 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: take('funcstoragea17ca${uniqueString(resourceGroup().id)}', 24)
  kind: 'StorageV2'
  location: location
  sku: {
    name: 'Standard_GRS'
  }
  properties: {
    accessTier: 'Hot'
    allowSharedKeyAccess: false
    isHnsEnabled: false
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
  tags: {
    'aspire-resource-name': 'funcstoragea17ca'
  }
}

output blobEndpoint string = funcstoragea17ca.properties.primaryEndpoints.blob

output dataLakeEndpoint string = funcstoragea17ca.properties.primaryEndpoints.dfs

output queueEndpoint string = funcstoragea17ca.properties.primaryEndpoints.queue

output tableEndpoint string = funcstoragea17ca.properties.primaryEndpoints.table

output name string = funcstoragea17ca.name

output id string = funcstoragea17ca.id