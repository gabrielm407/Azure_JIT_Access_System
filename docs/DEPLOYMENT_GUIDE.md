# JIT Access System - Deployment Guide

## Quick Start (5 Minutes)

### Prerequisites
```powershell
# 1. Verify Terraform
terraform version  # Should be >= 1.0

# 2. Install Azure CLI
az --version

# 3. Set environment variables
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"
$env:ARM_TENANT_ID = "your-tenant-id"
$env:ARM_CLIENT_ID = "your-client-id"
$env:ARM_CLIENT_SECRET = "your-client-secret"

# 4. Test Azure authentication
az login --service-principal `
  -u $env:ARM_CLIENT_ID `
  -p $env:ARM_CLIENT_SECRET `
  --tenant $env:ARM_TENANT_ID
```

### Deploy in 3 Steps
```bash
# Step 1: Initialize Terraform
cd c:\Users\Admin\Desktop\GitHub Projects\Azure_kubernetes_terraform
terraform init

# Step 2: Review deployment plan
terraform plan

# Step 3: Deploy infrastructure
terraform apply
```

---

## What Gets Deployed

### Core Infrastructure
- ✅ **Azure Resource Group** - Logical container for all resources
- ✅ **Virtual Network** (10.0.0.0/16) - Network isolation
- ✅ **Subnet** (10.0.0.0/24) - Private subnet for Function
- ✅ **Network Security Group** - Firewall rules for VNet

### SQL Server & Database
- ✅ **Azure SQL Server** (Private endpoint only)
  - No public IP
  - TDE encryption enabled
  - Managed Identity assigned
  - **Cost**: $15/month
  
- ✅ **Azure SQL Database (sentineldb)**
  - TDE encrypted at rest
  - GRS backup replication
  - Automatic daily snapshots
  - **Cost**: ~$10/month

### JIT Access Engine
- ✅ **Azure Function (RequestAccess)**
  - C# .NET 8 Isolated runtime
  - HTTP POST trigger
  - Managed Identity for SQL access
  - **Cost**: Serverless (~$0-5/month)

### Monitoring & Logging
- ✅ **Storage Account**
  - GRS replication
  - Audit log containers
  - **Cost**: ~$5-10/month
  
- ✅ **Application Insights**
  - Function telemetry
  - Performance monitoring
  - Anomaly detection
  - **Cost**: Included

### Network Security
- ✅ **Private Endpoint** (SQL Server)
  - Secure VNet connection
  - No internet exposure
  - **Cost**: $0.35/month

- ✅ **Private DNS Zone**
  - Internal hostname resolution
  - database.windows.net mapping
  - **Cost**: FREE

---

## Full Deployment Walkthrough

### Step 1: Navigate to Project Directory
```bash
cd "c:\Users\Admin\Desktop\GitHub Projects\Azure_kubernetes_terraform"
ls  # Verify you see aks.tf, variables.tf, etc.
```

### Step 2: Create terraform.tfvars
```bash
# Create configuration file with your values
cat > terraform.tfvars << EOF
resource_group_name = "my-resource-group"
location             = "eastus"
ARM_SUBSCRIPTION_ID  = "your-sub-id-here"
ARM_TENANT_ID        = "your-tenant-id-here"
ARM_CLIENT_ID        = "your-client-id-here"
ARM_CLIENT_SECRET    = "your-client-secret-here"
sql_admin_username   = "sqladmin"
sql_admin_password   = "ComplexP@ssw0rd!"
EOF
```

### Step 3: Initialize Terraform
```bash
terraform init

# Expected output:
# Terraform has been successfully configured!
# You may now begin working with Terraform.
```

### Step 4: Validate Configuration
```bash
terraform validate

# Expected output:
# Success! The configuration is valid.
```

### Step 5: Preview Deployment
```bash
terraform plan -out=tfplan

# Expected output shows:
# Plan: 20 to add, 0 to change, 0 to destroy.
```

### Step 6: Review Plan
```bash
# Review tfplan to ensure correct resources will be created
terraform show tfplan
```

### Step 7: Deploy Infrastructure
```bash
terraform apply tfplan

# Expected output:
# Apply complete! Resources: 20 added, 0 changed, 0 destroyed.
```

### Step 8: Retrieve Output Values
```bash
# Get important resource details
terraform output

# Individual outputs:
terraform output function_url
terraform output sql_server_name
terraform output storage_account_name
```

---

## Verification Steps

### 1. Verify SQL Server
```bash
# Check SQL Server exists and is private
az sql server show \
  --resource-group my-resource-group \
  --name my-sql-server

# Expected: No publicNetworkAccessEnabled field (means private)
```

### 2. Verify Private Endpoint
```bash
# List private endpoints
az network private-endpoint list \
  --resource-group my-resource-group \
  --query "[].{Name:name, Status:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}"
```

### 3. Verify Azure Function
```bash
# Check function app deployed
az functionapp show \
  --resource-group my-resource-group \
  --name jit-access-function \
  --query "{name:name, state:state, runtime:runtime, identity:identity}"
```

### 4. Verify Storage Account
```bash
# Check storage account created
az storage account show \
  --resource-group my-resource-group \
  --name YOUR_STORAGE_ACCOUNT_NAME \
  --query "{name:name, encryption:encryption, https_only:httpsTrafficOnlyEnabled}"
```

### 5. Verify Application Insights
```bash
# Check monitoring enabled
terraform output application_insights_id
```

---

## Testing JIT Access

### Test 1: Get Your Public IP
```powershell
# Option 1: Using PowerShell
[System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) | ForEach-Object {
    if ($_.AddressFamily -eq "InterNetwork") { $_.IPAddressToString }
}

# Option 2: Using curl
curl ifconfig.me

# Example output: 203.0.113.42
```

### Test 2: Request JIT Access
```bash
# Get your function URL from Terraform output
$FUNCTION_URL = terraform output function_url

# Request access for 1 hour
curl -X POST "$FUNCTION_URL/api/RequestAccess" `
  -H "Content-Type: application/json" `
  -d '{
    "ip": "203.0.113.42"
  }'

# Expected response:
# {
#   "status": "Access Granted",
#   "expires": "2026-01-28T15:30:45Z",
#   "rule": "JIT_a1b2c3d4_638419105445678901",
#   "duration": "1 hour"
# }
```

### Test 3: Verify Firewall Rule Created
```bash
# Check SQL Server firewall rules
az sql server firewall-rule list \
  --resource-group my-resource-group \
  --server my-sql-server

# Should show your new JIT_* rule
```

### Test 4: Connect to Database
```bash
# Use SQL Server Management Studio or sqlcmd
sqlcmd -S my-sql-server.database.windows.net `
  -U sqladmin `
  -P "ComplexP@ssw0rd!" `
  -d sentineldb

# Run a test query
> SELECT @@SERVERNAME AS ServerName, DB_NAME() AS DatabaseName
> GO
```

### Test 5: Verify Audit Logs
```bash
# Check audit logs in storage account
az storage blob list \
  --container-name jit-access-logs \
  --account-name YOUR_STORAGE_ACCOUNT_NAME \
  --query "[].name"
```

---

## Configuration Options

### Option 1: Minimal Deployment (Service-Managed Encryption)
```bash
terraform apply
```
- **Cost**: ~$30-35/month
- **Features**: JIT access, TDE, private endpoint, monitoring

### Option 2: Enhanced Deployment (All Features)
```bash
# Already deployed - see full feature set above
terraform apply
```

### Option 3: Development Environment (Cost-Optimized)
```bash
# Deploy, then destroy when not in use
terraform destroy
```
- **Cost**: Only when deployed
- **Use Case**: Testing and development

---

## Troubleshooting Deployment

### Error: "Unauthorized: Client does not have authorization"
**Cause**: Invalid Azure credentials
**Solution**:
```powershell
# Verify credentials
az login --service-principal `
  -u $env:ARM_CLIENT_ID `
  -p $env:ARM_CLIENT_SECRET `
  --tenant $env:ARM_TENANT_ID

# Verify subscription
az account set --subscription $env:ARM_SUBSCRIPTION_ID
```

### Error: "Error creating SQL Server - Code: BadRequest"
**Cause**: SQL Server name already exists (globally unique)
**Solution**:
```bash
# Change SQL server name in variables
terraform plan -var="sql_server_name=unique-name-$(date +%s)"
```

### Error: "Error building ArmClient - Request Error"
**Cause**: Service principal doesn't have correct role
**Solution**:
```bash
# Assign Contributor role to service principal
az role assignment create \
  --assignee $env:ARM_CLIENT_ID \
  --role "Contributor" \
  --scope "/subscriptions/$env:ARM_SUBSCRIPTION_ID"
```

### Error: "Function deployment failed"
**Cause**: Missing C# project files or dependencies
**Solution**:
```bash
# Rebuild C# project
cd src
dotnet build
dotnet publish -c Release -o ../publish
cd ..
```

### Error: "The deployment exceeded the quota"
**Cause**: Azure subscription quota exceeded
**Solution**:
```bash
# Check current usage
az vm list --query "length([*])"

# Request quota increase in Azure Portal
# Subscriptions > Usage + quotas > Request increase
```

---

## Post-Deployment Configuration

### 1. Configure Email Alerts
```bash
# Add email notifications
az monitor metrics alert create \
  --name "JIT-Access-Alert" \
  --resource-group my-resource-group \
  --scopes $(terraform output function_id) \
  --condition "avg FunctionExecutionCount > 10" \
  --window-size 1h \
  --evaluation-frequency 1m
```

### 2. Setup Dashboard
```bash
# Create monitoring dashboard in Azure Portal:
# 1. Dashboard > Create dashboard
# 2. Add tiles:
#    - Function executions
#    - Firewall rule count
#    - Storage account size
#    - Failed requests
```

### 3. Configure Backup Strategy
```bash
# SQL Database backups are automatic
# Configure long-term retention:
az sql db ltr-backup-show \
  --resource-group my-resource-group \
  --server my-sql-server \
  --database sentineldb
```

### 4. Set Up Audit Log Retention
```bash
# Configure audit storage lifecycle
az storage account management-policy create \
  --account-name YOUR_STORAGE_ACCOUNT \
  --resource-group my-resource-group \
  --policy '{"rules": [{"name": "archive-old-logs", "enabled": true, "type": "Lifecycle", "definition": {"actions": {"baseBlob": {"deleteAfterDays": 90}}}}]}'
```

---

## Maintenance Tasks

### Weekly
- ✅ Review audit logs for suspicious activity
- ✅ Check Application Insights for errors
- ✅ Monitor storage account growth

### Monthly
- ✅ Review JIT access patterns
- ✅ Verify SQL Server backups
- ✅ Check for Azure security advisories

### Quarterly
- ✅ Rotate SQL admin password
- ✅ Update Azure CLI and Terraform
- ✅ Review cost optimization opportunities

### Annually
- ✅ Full security audit
- ✅ Disaster recovery drill
- ✅ Compliance assessment

---

## Destroying Infrastructure

When no longer needed:

```bash
# Confirm resources to be destroyed
terraform plan -destroy

# Permanently delete resources
terraform destroy

# Confirm deletion (type 'yes')
# Expected output: Destroy complete! Resources: 20 destroyed.
```

**Warning**: This cannot be undone. Backups and audit logs are deleted.

---

## Cost Estimation

### Monthly Costs
```
SQL Server              $15.00
SQL Database           ~$10.00
Azure Function          $0-5.00
Storage Account         $5-10.00
Private Endpoint        $0.35
------------------------
TOTAL                 $30-40/month
```

### Optimizing Costs
1. Use consumption-based function pricing (not App Service Plan)
2. Archive old audit logs after 90 days
3. Use serverless SQL Database tier
4. Clean up unused private endpoints

### Estimating for Your Organization
```bash
# Get detailed pricing
terraform output cost_breakdown
```

---

## Support & Next Steps

1. **Review Architecture**: See [ARCHITECTURE_DIAGRAM.md](ARCHITECTURE_DIAGRAM.md)
2. **Understand Implementation**: See [COMPLIANCE_IMPLEMENTATION.md](COMPLIANCE_IMPLEMENTATION.md)
3. **Quick Reference**: See [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
4. **Troubleshooting**: See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md#troubleshooting-deployment)

---

## Emergency Access (If Function Fails)

If the JIT function is down, emergency SQL access:

```bash
# Manually create firewall rule (use with caution)
az sql server firewall-rule create \
  --resource-group my-resource-group \
  --server my-sql-server \
  --name "EMERGENCY_ACCESS" \
  --start-ip-address YOUR_IP \
  --end-ip-address YOUR_IP

# REMEMBER: Delete this rule immediately after
az sql server firewall-rule delete \
  --resource-group my-resource-group \
  --server my-sql-server \
  --name "EMERGENCY_ACCESS"
```

