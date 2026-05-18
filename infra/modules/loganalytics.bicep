@description('Environment name used as a suffix for all resources')
param environmentName string

@description('Azure region for the workspace')
param location string

// ── Log Analytics Workspace ────────────────────────────────────────────────
resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${environmentName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// ── Outputs ────────────────────────────────────────────────────────────────
@description('Log Analytics workspace resource ID (used by diagnostic settings)')
output workspaceId string = workspace.id

@description('Log Analytics workspace resource ID (alias)')
output workspaceResourceId string = workspace.id
