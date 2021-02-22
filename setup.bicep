param KeyVaultName string {
  default: '${resourceGroup().name}-dogfood-kv'
  minLength: 3
  maxLength: 24
  metadata: {
    description: 'The name of the key vault for storing necessary secrets.'
  }
}

param UserObjectId string {
  metadata: {
    description: 'Signed in user objectId'
  }
}

param HubName string {
  default: '${resourceGroup().name}-dogfood-hub'
  metadata: {
    description: 'The name of the main IoT hub instance.'
  }
}

param DpsName string {
  default: '${resourceGroup().name}-dogfood-dps'
  metadata: {
    description: 'The name of DPS instance.'
  }
}

param TsiName string {
  default: '${resourceGroup().name}-dogfood-tsi'
  metadata: {
    description: 'The name of TSI instance.'
  }
}

param TsiStorageAccountName string {
  default: '${resourceGroup().name}dogfoodstorage'
  metadata: {
    description: 'The storage account name used by TSI instance.'
  }
}

param AzureMapsAccountName string {
  default: '${resourceGroup().name}-dogfood-maps'
  metadata: {
    description: 'The azure maps account name.'
  }
}

resource iotHub 'Microsoft.Devices/IotHubs@2020-08-01' = {
  name: HubName
  location: resourceGroup().location
  properties: {
    routing: {
      routes: [
        {
          name: 'deviceLifecycle'
          source: 'DeviceLifecycleEvents'
          isEnabled: true
          endpointNames: [
            'events'
          ]
        }
        {
          name: 'digitalTwinChanges'
          source: 'DigitalTwinChangeEvents'
          isEnabled: true
          endpointNames: [
            'events'
          ]
        }
      ]
    }
  }
  sku: {
    name: 'S1'
    capacity: 1
  }
}

resource appConsumerGroup 'Microsoft.Devices/IotHubs/eventHubEndpoints/ConsumerGroups@2020-03-01' = {
  name: '${iotHub.name}/events/serviceapp'
  properties: {
  }
}

resource tsiConsumerGroup 'Microsoft.Devices/IotHubs/eventHubEndpoints/ConsumerGroups@2020-03-01' = {
  name: '${iotHub.name}/events/tsi'
  properties: {
  }
}

resource provisioningService 'Microsoft.Devices/provisioningServices@2017-11-15' = {
  name: DpsName
  location: resourceGroup().location
  sku: {
    name: 'S1'
    capacity: 1
  }
  properties: {
    iotHubs: [
      {
        location: resourceGroup().location
        connectionString: 'HostName=${iotHub.name}.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=${listkeys(hubKeysId, '2020-01-01').primaryKey}'
      }
    ]
  }
}

resource tsiStorageAccount 'Microsoft.Storage/storageAccounts@2018-02-01' = {
  name: TsiStorageAccountName
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: { 
    isHnsEnabled: false
  }
}

resource tsi 'Microsoft.TimeSeriesInsights/environments@2020-05-15' = {
  name: TsiName
  location: resourceGroup().location
  kind: 'Gen2'
  sku: {
    name:'L1'
    capacity: 1
  }
  properties: {
    storageConfiguration: {
      accountName: tsiStorageAccount.name
      managementKey: '${listkeys(tsiStorageAccount.id, '2018-02-01').keys[0].value}'
    }
    timeSeriesIdProperties: [
      {
        name: 'iothub-connection-device-id'
        type: 'String'
      }
    ]
  }
}

var hubKeysId = resourceId('Microsoft.Devices/IotHubs/Iothubkeys', HubName, 'iothubowner')
resource tsiEventSource 'Microsoft.TimeSeriesInsights/environments/eventsources@2020-05-15' = {
  name: '${tsi.name}/dogfoodsource'
  kind: 'Microsoft.IoTHub'
  location: resourceGroup().location
  properties: {
    iotHubName: iotHub.name
    consumerGroupName: tsiConsumerGroup.name
    eventSourceResourceId: iotHub.id
    keyName: 'iothubowner'
    sharedAccessKey: '${listkeys(hubKeysId, '2019-11-04').primaryKey}'
    timestampPropertyName: 'iothub-connection-device-id'
  }
}

resource azureMaps 'Microsoft.Maps/accounts@2020-02-01-preview' = {
  name: AzureMapsAccountName
  location: 'global'
  sku: {
    name: 'S0'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2018-02-14' = {
  name: KeyVaultName
  location: resourceGroup().location
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    accessPolicies: [
      {
        objectId: UserObjectId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'all'
          ]
          certificates: [
            'all'
          ]
          keys: [
            'all'
          ]
        }
      }
    ]
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    enableSoftDelete: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
      ipRules: [
      ]
      virtualNetworkRules: [
      ]
    }
  }
}

resource iotHubConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: concat('${keyVault.name}', '/IotHubConnectionString')
  properties: {
    value: 'HostName=${iotHub.name}.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=${listkeys(hubKeysId, '2019-11-04').primaryKey}'
  }
}

resource eventHubEndpoint 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: concat('${keyVault.name}', '/EventHubEndpoint')
  properties: {
    value: '${iotHub.properties.eventHubEndpoints.events.endpoint}'
  }
}

resource dpsScopeId 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: concat('${keyVault.name}', '/DpsScopeId')
  properties: {
    value: '${provisioningService.properties.idScope}'
  }
}

var dpsKeysId = resourceId('Microsoft.Devices/ProvisioningServices/keys', DpsName, 'provisioningserviceowner')
resource dpsPrimaryKey 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: concat('${keyVault.name}', '/DpsPrimaryKey')
  properties: {
    value: '${listkeys(dpsKeysId, '2017-11-15').primaryKey}'
  }
}

var azureMapsKeysId = resourceId('Microsoft.Maps/accounts', AzureMapsAccountName)
resource azureMapsPrimaryKey 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: concat('${keyVault.name}', '/AzureMapsPrimaryKey')
  properties: {
    value: '${listkeys(azureMapsKeysId, '2020-02-01-preview').primaryKey}'
  }
}
