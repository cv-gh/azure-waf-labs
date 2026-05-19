@description('Environment name used as a suffix for all resources')
param environmentName string

@description('Azure region for the SQL resources')
param location string

@description('Display name of the App Service (used as the SQL AAD admin login label)')
param appServiceName string

@description('Object ID of the App Service system-assigned managed identity — becomes the SQL AAD admin')
param appServicePrincipalId string

// Built-in Azure RBAC role: SQL DB Contributor
var sqlDbContributorRoleId = '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec'

var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)

// ── SQL Server ─────────────────────────────────────────────────────────────
// The App Service MSI is set as the AAD admin so it can connect without
// a separate CREATE USER step, satisfying the MCAPS AAD-only-auth policy.
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: 'sql-${environmentName}-${uniqueSuffix}'
  location: location
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      login: appServiceName
      sid: appServicePrincipalId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true
    }
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Allow Azure services to reach the SQL server (required for App Service MSI)
resource firewallAllowAzure 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ── Database (Free serverless tier) ───────────────────────────────────────
resource database 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: 'waflab'
  location: location
  sku: {
    name: 'GP_S_Gen5_1'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368
    useFreeLimit: true
    freeLimitExhaustionBehavior: 'AutoPause'
    autoPauseDelay: 60
    minCapacity: '0.5'
    zoneRedundant: false
  }
}

// ── RBAC: grant App Service MSI the SQL DB Contributor role ───────────────
resource sqlRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(appServicePrincipalId)) {
  name: guid(sqlServer.id, appServicePrincipalId, sqlDbContributorRoleId)
  scope: sqlServer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sqlDbContributorRoleId)
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ── Outputs ────────────────────────────────────────────────────────────────
@description('Fully qualified domain name of the SQL server')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('Name of the waflab database')
output databaseName string = database.name