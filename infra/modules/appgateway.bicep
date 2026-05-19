@description('Environment name used as a suffix for all resources')
param environmentName string

@description('Azure region for the Application Gateway resources')
param location string

@description('Default hostname of the backend App Service (no protocol prefix)')
param backendFqdn string

@description('Resource ID of the Log Analytics workspace for diagnostic settings')
param logWorkspaceId string

// ── Public IP ──────────────────────────────────────────────────────────────
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'pip-agw-${environmentName}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'agw-${environmentName}'
    }
  }
}

// ── WAF Policy ─────────────────────────────────────────────────────────────
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-11-01' = {
  name: 'waf-policy-${environmentName}'
  location: location
  properties: {
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      // Lab 1 starting state — switch to Prevention in Lab 3
      mode: 'Detection'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
        }
      ]
      exclusions: [] // Rule Exclusions added via CLI in Lab 3
    }
    customRules: [] // Custom Rules added via CLI in Lab 4
  }
}

// ── Application Gateway ────────────────────────────────────────────────────
var agwName = 'agw-${environmentName}'
var frontendIpConfigName = 'frontendIpConfig'
var frontendPortName = 'frontendPort80'
var backendPoolName = 'backendPool'
var backendHttpSettingsName = 'backendHttpSettings'
var httpListenerName = 'httpListener'
var routingRuleName = 'routingRule'
var healthProbeName = 'healthProbe'

resource appGateway 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: agwName
  location: location
  properties: {
    firewallPolicy: {
      id: wafPolicy.id
    }
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: agwSubnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontendIpConfigName
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendPortName
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
        properties: {
          backendAddresses: [
            {
              fqdn: backendFqdn
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettingsName
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 30
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', agwName, healthProbeName)
          }
        }
      }
    ]
    probes: [
      {
        name: healthProbeName
        properties: {
          protocol: 'Https'
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          match: {
            statusCodes: ['200-399']
          }
        }
      }
    ]
    httpListeners: [
      {
        name: httpListenerName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', agwName, frontendIpConfigName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', agwName, frontendPortName)
          }
          protocol: 'Http'
          firewallPolicy: {
            id: wafPolicy.id
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: routingRuleName
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', agwName, httpListenerName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agwName, backendPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', agwName, backendHttpSettingsName)
          }
        }
      }
    ]
  }
  dependsOn: [agwVnet]
}

// ── VNet & Subnet (required by App Gateway) ────────────────────────────────
resource agwVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-agw-${environmentName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'agw-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

resource agwSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: agwVnet
  name: 'agw-subnet'
}

// ── Diagnostic Settings ────────────────────────────────────────────────────
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logWorkspaceId)) {
  name: 'diag-${agwName}'
  scope: appGateway
  properties: {
    workspaceId: logWorkspaceId
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
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
@description('Public IP address of the Application Gateway')
output publicIpAddress string = publicIp.properties.ipAddress

@description('Name of the Application Gateway resource')
output appGatewayName string = appGateway.name

@description('Name of the WAF Policy resource')
output wafPolicyName string = wafPolicy.name
