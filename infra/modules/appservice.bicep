@description('Environment name used as a suffix for all resources')
param environmentName string

@description('Azure region for the App Service resources')
param location string

@description('Fully qualified domain name of the Azure SQL server')
param sqlServerFqdn string

@description('Name of the Azure SQL database')
param databaseName string

@description('Resource ID of the Log Analytics workspace for diagnostic settings')
param logWorkspaceId string

// ── App Service Plan ───────────────────────────────────────────────────────
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'asp-${environmentName}'
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true // required for Linux
  }
}

// ── App Service ────────────────────────────────────────────────────────────
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: 'app-${environmentName}-${uniqueSuffix}'
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.12'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AZURE_SQL_SERVER'
          value: sqlServerFqdn
        }
        {
          name: 'AZURE_SQL_DATABASE'
          value: databaseName
        }
        {
          name: 'AZURE_SQL_USE_MSI'
          value: 'true'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
  }
}

// ── Diagnostic Settings ────────────────────────────────────────────────────
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logWorkspaceId)) {
  name: 'diag-${appService.name}'
  scope: appService
  properties: {
    workspaceId: logWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ── Outputs ────────────────────────────────────────────────────────────────
@description('Default hostname of the App Service (without protocol)')
output appServiceUrl string = appService.properties.defaultHostName

@description('Object ID of the system-assigned managed identity')
output principalId string = appService.identity.principalId

@description('Name of the App Service resource')
output appServiceName string = appService.name
