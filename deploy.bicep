param ServerFarmName string {
  default: '${resourceGroup().name}-dogfood-srv'
  metadata: {
    description: 'The name of the server farm to host the cloud app.'
  }
}

param WebsiteName string {
  default: '${resourceGroup().name}-dogfood-website'
  metadata: {
    description: 'The name of the website to host the cloud app.'
  }
}

resource serverfarm 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: ServerFarmName
  location: resourceGroup().location
  sku: {
    name: 'S1'
    tier: 'Standard'
    size: 'S1'
    family: 'S'
    capacity: 1
  }
  kind: 'app'
}

resource website 'Microsoft.Web/sites@2020-06-01' = {
  name: WebsiteName
  location: resourceGroup().location
  properties: {
    serverFarmId: serverfarm.id    
  }
}

resource sourceControl 'Microsoft.Web/sites/sourcecontrols@2020-06-01' = {
  name: '${website.name}/web'
  properties: {    
    repoUrl: 'https://github.com/vinagesh/iotdogfood.git'
    branch: 'master'
    isManualIntegration: true
  }
}