targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Environment name used as a suffix for all resources')
param environmentName string

// ── Log Analytics (no dependencies) ───────────────────────────────────────
module loganalytics 'modules/loganalytics.bicep' = {
  name: 'loganalytics'
  params: {
    environmentName: environmentName
    location: location
  }
}

// ── App Service — first pass to obtain the system-assigned identity ────────
// SQL settings are empty here; updated by appserviceConfig once SQL is ready.
module appservice 'modules/appservice.bicep' = {
  name: 'appservice'
  params: {
    environmentName: environmentName
    location: location
    sqlServerFqdn: ''
    databaseName: ''
    logWorkspaceId: loganalytics.outputs.workspaceId
  }
}

// ── SQL (depends on appservice to receive its managed identity principal ID)
module sql 'modules/sql.bicep' = {
  name: 'sql'
  params: {
    environmentName: environmentName
    location: location
    appServiceName: appservice.outputs.appServiceName
    appServicePrincipalId: appservice.outputs.principalId
  }
}

// ── App Service config update — injects SQL connection settings ────────────
module appserviceConfig 'modules/appservice.bicep' = {
  name: 'appserviceConfig'
  params: {
    environmentName: environmentName
    location: location
    sqlServerFqdn: sql.outputs.sqlServerFqdn
    databaseName: sql.outputs.databaseName
    logWorkspaceId: loganalytics.outputs.workspaceId
  }
}

// ── Application Gateway (depends on the fully configured App Service) ──────
module appgateway 'modules/appgateway.bicep' = {
  name: 'appgateway'
  params: {
    environmentName: environmentName
    location: location
    backendFqdn: appservice.outputs.appServiceUrl
    logWorkspaceId: loganalytics.outputs.workspaceId
  }
  dependsOn: [appserviceConfig]
}

// ── Outputs ────────────────────────────────────────────────────────────────
output appGatewayPublicIp string = appgateway.outputs.publicIpAddress
output appServiceUrl string = appservice.outputs.appServiceUrl
output sqlServerName string = sql.outputs.sqlServerFqdn
