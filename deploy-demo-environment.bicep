param location string = 'australiaeast'

@secure()
param secretValue string


// Replace these with your own principals to provide RBAC to the Key Vault
var keyVaultRoleAssignments = [
  // Provide RBAC to the key vault for the GitHub Service Principal
  {
    principalId: 'cbd79400-cab6-4568-93fd-36a676a09f0f'
    roleDefinitionIdOrName: 'Key Vault Secrets Officer'
    principalType: 'ServicePrincipal'
  }
  // Provide RBAC to the key vault for my user account
  {
    principalId: 'e22e2af2-e4ce-409c-8b57-cd6a1f3e1ac2'
    roleDefinitionIdOrName: 'Key Vault Secrets Officer'
    principalType: 'User'
  }
]

// This is used in the naming standard of all resources
var resourcePrefix = 'gh-runner-demo'

targetScope = 'subscription'

module rg 'br/public:avm/res/resources/resource-group:0.2.3' = {
  name: '${resourcePrefix}-rg-001'
  params: {
    name: '${resourcePrefix}-rg-001'
    location: location
  }
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.5' = {
  name: '${resourcePrefix}-vnet-001'
  scope: resourceGroup(rg.name)
  params: {
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    name: '${resourcePrefix}-vnet-001'
    location: location
    subnets: [
      {
        addressPrefix: '10.0.0.0/24'
        name: '${resourcePrefix}-subnet-001'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        addressPrefix: '10.0.1.0/24'
        name: '${resourcePrefix}-subnet-002'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    ]
  }
}

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.2.4' = {
  name: 'privatelink.vaultcore.azure.net'
  scope: resourceGroup(rg.name)
  params: {
    name: 'privatelink.vaultcore.azure.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        registrationEnabled: true
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}


module keyVault 'br/public:avm/res/key-vault/vault:0.4.0' = {
  name: '${resourcePrefix}-kv-001'
  scope: resourceGroup(rg.name)
  params: {
    name: '${resourcePrefix}-kv-001'
    location: location
    enablePurgeProtection: false
    enableSoftDelete: true
    publicNetworkAccess: 'Disabled'
    roleAssignments: keyVaultRoleAssignments
    secrets: {
      secureList: [
        {
          name: 'mySuperSecret'
          value: secretValue
        }
      ]
    }
    privateEndpoints: [
      {
        name: '${resourcePrefix}-kv-pe-001'
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
        privateDnsZoneResourceIds: [
          privateDnsZone.outputs.resourceId
        ]
        privateDnsZoneGroupName: 'default'
      }
    ]
  }
}
