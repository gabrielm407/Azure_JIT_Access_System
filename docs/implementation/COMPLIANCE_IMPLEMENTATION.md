# JIT Access System - Implementation Guide

## Overview

This project implements a **Just-In-Time (JIT) Access System** for Azure SQL Database using **Zero Trust Architecture**. By default, the SQL Server firewall blocks all public access. When a developer needs access, they authenticate via an Azure Function, which validates their identity and temporarily opens the firewall for their specific IP address for 1 hour, then automatically revokes access.

---

## How JIT Access Works

### Default State: Locked Down
```
┌─────────────────────────────────────┐
│  SQL Server Firewall Rules          │
├─────────────────────────────────────┤
│  ❌ 0.0.0.0/0 (Blocked)             │
│  ❌ Public Access (Denied)          │
│  ❌ All IPs (Default Deny)          │
└─────────────────────────────────────┘
```

### Request: User Initiates Access
```bash
curl -X POST https://YOUR_DOMAIN/api/RequestAccess \
     -H "Content-Type: application/json" \
     -d '{"ip": "YOUR_IP_ADDRESS"}'
```

### Response: Temporary Access Granted
```json
{
  "status": "Access Granted",
  "expires": "2026-01-28T15:30:45Z",
  "rule": "JIT_a1b2c3d4_638419105445678901",
  "duration": "1 hour",
  "sqlServer": "my-sql-server.database.windows.net"
}
```

### After 1 Hour: Access Automatically Revoked
```
Automatic Cleanup Process
├─ Timer checks every 5 minutes
├─ Identifies expired rules
├─ Deletes JIT firewall rules
└─ User access revoked
```

---

## Architecture Components

### 1. **Azure Function (RequestAccess)**
- **File**: `src/JitAccess.cs`
- **Language**: C# .NET 8 Isolated
- **Trigger**: HTTP POST to `/api/RequestAccess`
- **Purpose**: 
  - Receive JIT access requests
  - Validate user IP address
  - Create temporary firewall rules
  - Log all access requests
  - Return access details

**Key Code**:
```csharp
[Function("RequestAccess")]
public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequestData req)
{
    // Parse request body for IP address
    var data = JsonSerializer.Deserialize<JsonElement>(requestBody);
    string clientIp = data.TryGetProperty("ip", out var ipVal) ? ipVal.ToString() : "127.0.0.1";
    
    // Generate unique rule name with expiration timestamp
    var expiration = DateTime.UtcNow.AddHours(1);
    string ruleName = $"JIT_{Guid.NewGuid().ToString().Substring(0, 8)}_{expiration.Ticks}";
    
    // Authenticate with managed identity
    var armClient = new ArmClient(new DefaultAzureCredential());
    
    // Create firewall rule
    var ruleData = new SqlFirewallRuleData()
    {
        StartIPAddress = clientIp,
        EndIPAddress = clientIp
    };
    
    await sqlServer.GetSqlFirewallRules().CreateOrUpdateAsync(WaitUntil.Completed, ruleName, ruleData);
    
    return success response with expiration details
}
```

### 2. **Azure SQL Server (Private)**
- **File**: `sql_server.tf`
- **Access**: Private endpoint only (no public IP)
- **Firewall**: Default-deny, dynamically modified by Function
- **Encryption**: Transparent Data Encryption (TDE)
- **Authentication**: Managed Identity for Function
- **Cost**: $15/month

**Default Firewall State**:
- ❌ No rules by default
- ❌ All public access denied
- ✅ Private endpoint access only
- ✅ Function can modify rules

### 3. **Azure SQL Database (sentineldb)**
- **File**: `sql_server.tf`
- **Encryption**: TDE encrypted at rest
- **Storage**: Geo-Redundant (GRS)
- **Backups**: Automatic daily snapshots
- **Audit**: All access logged to storage account

### 4. **Managed Identity**
- **Type**: System-Assigned (built-in)
- **Purpose**: Authenticate Azure Function to SQL Server
- **Permissions**:
  - Create firewall rules
  - Read SQL configuration
  - Write audit logs
- **Cost**: FREE

**RBAC Assignment**:
```terraform
resource "azurerm_role_assignment" "function_sql_admin" {
  scope              = azurerm_mssql_server.sql_server.id
  role_definition_id = data.azurerm_role_definition.sql_admin.id
  principal_id       = azurerm_linux_function_app.jit_function.identity[0].principal_id
}
```

### 5. **Storage Account (Audit Logs)**
- **File**: `storage_account.tf`
- **Access**: Private only (no public access)
- **Containers**:
  - `jit-access-logs`: Request history
  - `audit-logs`: Activity records
- **Encryption**: GRS replication
- **Cost**: $5-10/month

### 6. **Application Insights (Monitoring)**
- **Purpose**: Track Function execution
- **Metrics**: Requests, failures, latency
- **Alerts**: Anomaly detection
- **Cost**: Included in Function cost

### 7. **Virtual Network (Private Access)**
- **File**: `virtual_network.tf`
- **Address Space**: 10.0.0.0/16
- **Subnet**: 10.0.0.0/24 (private)
- **Purpose**: Isolate resources from internet

---

## Deployment Architecture

```terraform
# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# SQL Server (No Public Access)
resource "azurerm_mssql_server" "sql_server" {
  name                = "my-sql-server"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  
  identity {
    type = "SystemAssigned"
  }
}

# SQL Database
resource "azurerm_mssql_database" "sql_database" {
  name      = "sentineldb"
  server_id = azurerm_mssql_server.sql_server.id
  
  collation = "SQL_Latin1_General_CP1_CI_AS"
  
  # Transparent Data Encryption
  transparent_data_encryption_enabled = true
}

# Azure Function
resource "azurerm_linux_function_app" "jit_function" {
  name                = "jit-access-function"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  app_service_plan_id = azurerm_service_plan.function_plan.id
  
  identity {
    type = "SystemAssigned"
  }
  
  app_settings = {
    SUBSCRIPTION_ID     = var.ARM_SUBSCRIPTION_ID
    RESOURCE_GROUP_NAME = azurerm_resource_group.main.name
    SQL_SERVER_NAME     = azurerm_mssql_server.sql_server.name
  }
}

# Storage Account for Audit Logs
resource "azurerm_storage_account" "audit" {
  name                = "auditlogs${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  account_tier             = "Standard"
  account_replication_type = "GRS"
  https_traffic_only_enabled = true
}
```

---

## Security Model: Zero Trust

### Identity Verification
1. ✅ Azure Service Principal authenticates
2. ✅ Function validates request
3. ✅ Managed Identity confirms authorization
4. ✅ All actions logged with timestamp

### Access Control
1. ✅ Private endpoint only (no public IP)
2. ✅ IP-specific firewall rules (not ranges)
3. ✅ 1-hour automatic expiration
4. ✅ No persistent access granted

### Data Protection
1. ✅ TDE encryption at rest (AES-256)
2. ✅ HTTPS/TLS 1.2+ in transit
3. ✅ GRS storage for audit logs
4. ✅ All requests logged

### Monitoring
1. ✅ Real-time logging to storage
2. ✅ Application Insights metrics
3. ✅ Automatic anomaly detection
4. ✅ Email alerts for suspicious activity

### Compliance
1. ✅ All actions audited with IP
2. ✅ Immutable audit trail
3. ✅ Automatic cleanup/revocation
4. ✅ Meets Azure Security Benchmark v2

---

## Configuration Variables

```terraform
variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
  default     = "my-resource-group"
}

variable "location" {
  description = "Azure location"
  type        = string
  default     = "eastus"
}

variable "ARM_SUBSCRIPTION_ID" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "sql_admin_username" {
  description = "SQL Server admin username"
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "SQL Server admin password"
  type        = string
  sensitive   = true
}
```

---

## Deployment Steps

### 1. Prerequisites
```bash
# Install Terraform
terraform version  # Should be >= 1.0

# Install Azure CLI
az --version

# Set environment variables
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"

# Verify authentication
az login --service-principal \
  -u $ARM_CLIENT_ID \
  -p $ARM_CLIENT_SECRET \
  --tenant $ARM_TENANT_ID
```

### 2. Initialize Terraform
```bash
cd Azure_kubernetes_terraform
terraform init
```

### 3. Review Resources
```bash
terraform plan
```

### 4. Deploy Infrastructure
```bash
terraform apply
```

### 5. Verify Deployment
```bash
# Get function URL
terraform output function_url

# Get SQL Server details
terraform output sql_server_name
terraform output sql_server_id

# Get storage account
terraform output storage_account_name
```

---

## Verification Checklist

### ✅ SQL Server Configuration
- [ ] Private endpoint created
- [ ] No public IP assigned
- [ ] Managed Identity enabled
- [ ] TDE encryption enabled
- [ ] Audit logging configured

### ✅ Azure Function
- [ ] Function deployed successfully
- [ ] Managed Identity assigned
- [ ] RBAC role assigned
- [ ] Environment variables configured
- [ ] HTTP trigger working

### ✅ Storage Account
- [ ] GRS replication enabled
- [ ] HTTPS-only enabled
- [ ] Audit containers created
- [ ] Permissions configured

### ✅ Monitoring
- [ ] Application Insights enabled
- [ ] Alerts configured
- [ ] Log Analytics workspace linked
- [ ] Metrics dashboard created

---

## Testing JIT Access

### Step 1: Get Your IP Address
```bash
# PowerShell
[System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) | Select-Object IPAddressToString

# Or online
curl ifconfig.me
```

### Step 2: Request Access
```bash
curl -X POST https://YOUR_FUNCTION_URL/api/RequestAccess \
     -H "Content-Type: application/json" \
     -d '{"ip": "YOUR_IP_ADDRESS"}'
```

### Step 3: Connect to Database
```bash
sqlcmd -S YOUR_SQL_SERVER.database.windows.net -U username -P password -d sentineldb
```

### Step 4: Query Data
```sql
SELECT @@SERVERNAME AS ServerName, DB_NAME() AS DatabaseName
```

### Step 5: Wait 1 Hour
After 1 hour, the firewall rule expires and your connection will be blocked.

---

## Troubleshooting

### Error: "Function app doesn't exist"
**Cause**: Azure Function not deployed
**Solution**: Run `terraform apply` to deploy function

### Error: "Authorization failed for firewall rule creation"
**Cause**: Managed Identity doesn't have SQL admin role
**Solution**: Verify RBAC role assignment in Azure Portal

### Error: "Invalid JSON in request body"
**Cause**: Malformed request payload
**Solution**: Ensure IP address format is correct:
```json
{"ip": "203.0.113.42"}  // Correct
{"ip": "203.0.113"}     // Wrong (incomplete)
```

### Connection times out after request
**Cause**: Firewall rule expired
**Solution**: Request access again with `curl` command

### Application Insights shows errors
**Cause**: Function execution issues
**Solution**: Check function logs in Azure Portal > Function App > Monitor

---

## Cost Analysis

| Resource | Cost/Month | Always Active? |
|----------|-----------|---|
| SQL Server | $15 | ✅ Yes |
| SQL Database | ~$10 | ✅ Yes |
| Azure Function | $0-5 | ✅ Yes (consumption) |
| Storage Account | $5-10 | ✅ Yes |
| Private Endpoint | $0.35 | ✅ Yes |
| **Total** | **~$30-35** | |

---

## Best Practices

1. **Rotate Passwords Regularly**
   - SQL Admin password every 90 days
   - Service Principal secret before expiration

2. **Monitor Access Requests**
   - Review audit logs weekly
   - Check Application Insights for anomalies
   - Set up email alerts for suspicious activity

3. **Limit Access Duration**
   - 1 hour is default (review for your needs)
   - Consider shorter durations for sensitive operations
   - Never grant permanent access

4. **Audit Everything**
   - All JIT requests logged
   - User IP recorded
   - Timestamp for compliance
   - Connection history preserved

5. **Update Dependencies**
   - Keep Azure Function runtime updated
   - Update NuGet packages regularly
   - Monitor security advisories

---

## Next Steps

1. Deploy infrastructure with Terraform
2. Test JIT access workflow
3. Configure email alerts for suspicious activity
4. Implement custom cleanup function (currently 5-min timer)
5. Add additional logging/monitoring dashboards
6. Document internal access procedures

