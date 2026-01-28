# Quick Reference - JIT Access System

## 🚀 Request JIT Access (For Users)

### Get Your IP Address
```powershell
# PowerShell
[System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) | 
  ForEach-Object { if ($_.AddressFamily -eq "InterNetwork") { $_.IPAddressToString } }

# PowerShell (simple)
curl ifconfig.me

# Bash
hostname -I  # Linux
ifconfig     # macOS
```

**Example Output**: `203.0.113.42`

---

### Request 1-Hour Database Access

#### Option 1: Using curl (Linux/macOS)
```bash
curl -X POST https://YOUR_DOMAIN/api/RequestAccess \
     -H "Content-Type: application/json" \
     -d '{"ip": "203.0.113.42"}'
```

#### Option 2: Using PowerShell (Windows)
```powershell
$body = @{
    ip = "203.0.113.42"
} | ConvertTo-Json

Invoke-WebRequest -Uri "https://YOUR_DOMAIN/api/RequestAccess" `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -Body $body
```

#### Option 3: Using Postman
1. Create POST request to: `https://YOUR_DOMAIN/api/RequestAccess`
2. Headers: `Content-Type: application/json`
3. Body (raw JSON):
```json
{
  "ip": "203.0.113.42"
}
```

**Expected Response**:
```json
{
  "status": "Access Granted",
  "expires": "2026-01-28T15:30:45Z",
  "rule": "JIT_a1b2c3d4_638419105445678901",
  "duration": "1 hour",
  "sqlServer": "my-sql-server.database.windows.net"
}
```

---

### Connect to Database

#### Using SQL Server Management Studio (SSMS)
1. Open SSMS
2. Server: `my-sql-server.database.windows.net`
3. Auth: SQL Server Authentication
4. Login: `sqladmin`
5. Password: `YOUR_SQL_PASSWORD`
6. Database: `sentineldb`
7. Click Connect

#### Using sqlcmd (CLI)
```bash
sqlcmd -S my-sql-server.database.windows.net \
  -U sqladmin \
  -P "YOUR_SQL_PASSWORD" \
  -d sentineldb
```

#### Using Azure Data Studio
1. New Connection
2. Server: `my-sql-server.database.windows.net`
3. Database: `sentineldb`
4. Authentication: SQL Login
5. User: `sqladmin`
6. Password: `YOUR_SQL_PASSWORD`
7. Connect

---

### Test Connection
```sql
-- Check server name
SELECT @@SERVERNAME AS ServerName

-- Check database name
SELECT DB_NAME() AS DatabaseName

-- Check server time
SELECT GETUTC() AS ServerUTC, GETDATE() AS ServerLocal

-- Simple query
SELECT TOP 5 * FROM sys.tables
```

---

## 🔧 For Deployment (DevOps/Infrastructure)

### Prerequisites Checklist
```bash
# 1. Verify Terraform
terraform version
# Expected: Terraform v1.x or higher

# 2. Verify Azure CLI
az version
# Expected: 2.x or higher

# 3. Set environment variables
export ARM_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ARM_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ARM_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ARM_CLIENT_SECRET="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# 4. Test authentication
az login --service-principal \
  -u $ARM_CLIENT_ID \
  -p $ARM_CLIENT_SECRET \
  --tenant $ARM_TENANT_ID
```

### Deploy in 3 Steps
```bash
# Step 1: Initialize
cd "c:\Users\Admin\Desktop\GitHub Projects\Azure_kubernetes_terraform"
terraform init

# Step 2: Plan
terraform plan -out=tfplan

# Step 3: Apply
terraform apply tfplan
```

### Get Output Values
```bash
# All outputs
terraform output

# Individual outputs
terraform output function_url
terraform output sql_server_name
terraform output storage_account_name
terraform output function_id
terraform output sql_server_id
```

---

## ✅ Verification Commands

### Verify Resources Exist
```bash
# Check SQL Server
az sql server show \
  --resource-group my-resource-group \
  --name my-sql-server

# Check Database
az sql db show \
  --resource-group my-resource-group \
  --server my-sql-server \
  --name sentineldb

# Check Function App
az functionapp show \
  --resource-group my-resource-group \
  --name jit-access-function

# Check Storage Account
az storage account show \
  --resource-group my-resource-group \
  --name YOUR_STORAGE_ACCOUNT
```

### Verify Firewall Rules
```bash
# List all firewall rules
az sql server firewall-rule list \
  --resource-group my-resource-group \
  --server my-sql-server \
  --query "[].{Name:name, StartIP:startIpAddress, EndIP:endIpAddress}"

# Check if JIT rule exists
az sql server firewall-rule list \
  --resource-group my-resource-group \
  --server my-sql-server \
  --query "[?name.starts_with(@, 'JIT_')]"
```

### Verify Function Configuration
```bash
# Check function settings
az functionapp config appsettings list \
  --resource-group my-resource-group \
  --name jit-access-function

# Check function identity
az functionapp identity show \
  --resource-group my-resource-group \
  --name jit-access-function
```

---

## 🔍 Troubleshooting

### Common Issues & Solutions

#### Issue: "Invalid JSON in request"
**Problem**: Malformed request payload
**Solution**: Verify exact format:
```json
{"ip": "203.0.113.42"}
```
**NOT**:
```json
{ip: 203.0.113.42}
```

---

#### Issue: "Unauthorized" or "Forbidden"
**Problem**: Service Principal doesn't have permissions
**Solution**:
```bash
# Grant SQL Admin role
az role assignment create \
  --assignee-object-id YOUR_PRINCIPAL_ID \
  --role "SQL Server Contributor" \
  --scope /subscriptions/YOUR_SUBSCRIPTION_ID
```

---

#### Issue: "Firewall rule already exists"
**Problem**: Rule name collision (very rare)
**Solution**: Firewall rules use unique GUIDs - this shouldn't happen
**Workaround**: Wait a moment and try again

---

#### Issue: "Connection timeout"
**Problem**: Firewall rule expired (after 1 hour)
**Solution**: Request access again with the JIT API
```bash
curl -X POST https://YOUR_DOMAIN/api/RequestAccess \
     -H "Content-Type: application/json" \
     -d '{"ip": "203.0.113.42"}'
```

---

#### Issue: "Function returns error 500"
**Problem**: Function execution failed
**Solution**: Check Application Insights logs
```bash
# Get recent function logs
az functionapp log download \
  --resource-group my-resource-group \
  --name jit-access-function
```

---

#### Issue: "Can't find function URL"
**Problem**: Function not deployed or not running
**Solution**:
```bash
# Get function URL
terraform output function_url

# Or from Azure CLI
az functionapp show \
  --resource-group my-resource-group \
  --name jit-access-function \
  --query "defaultHostName"
```

---

#### Issue: "SQL Server not reachable"
**Problem**: Private endpoint not configured or network issue
**Solution**:
```bash
# Verify private endpoint
az network private-endpoint list \
  --resource-group my-resource-group

# Test connectivity from Function
# (Already configured - should work automatically)
```

---

## 📊 Monitoring Commands

### Check Function Invocations
```bash
# Get last 24 hours of invocations
az monitor metrics list \
  --resource /subscriptions/YOUR_SUB/resourceGroups/my-resource-group/providers/Microsoft.Web/sites/jit-access-function \
  --metric "FunctionExecutionCount" \
  --start-time 2026-01-27T00:00:00Z \
  --interval PT1H
```

### Check Storage Account Audit Logs
```bash
# List audit log blobs
az storage blob list \
  --container-name jit-access-logs \
  --account-name YOUR_STORAGE_ACCOUNT \
  --query "[].name"

# Download a specific log
az storage blob download \
  --container-name jit-access-logs \
  --name "log-filename.json" \
  --account-name YOUR_STORAGE_ACCOUNT \
  --file local-filename.json
```

### Check Application Insights
```bash
# Query recent traces
az monitor app-insights metrics show \
  --resource-group my-resource-group \
  --app YOUR_APP_INSIGHTS_NAME \
  --metric "requests/count"
```

---

## 🗑️ Cleanup Commands

### Delete Specific Firewall Rule
```bash
# Delete a JIT rule (use if cleanup didn't work)
az sql server firewall-rule delete \
  --resource-group my-resource-group \
  --server my-sql-server \
  --name "JIT_a1b2c3d4_638419105445678901"
```

### Delete All JIT Rules
```bash
# WARNING: This deletes all JIT rules!
# List JIT rules first
az sql server firewall-rule list \
  --resource-group my-resource-group \
  --server my-sql-server \
  --query "[?name.starts_with(@, 'JIT_')].name" \
  --output tsv | \
while read rule; do
  az sql server firewall-rule delete \
    --resource-group my-resource-group \
    --server my-sql-server \
    --name "$rule"
done
```

### Destroy All Infrastructure
```bash
# WARNING: This deletes everything!
terraform destroy

# Confirm by typing 'yes'
```

---

## 📈 Performance & Limits

### Function Limits
- Max response time: 10 seconds
- Max payload size: 100 MB
- Concurrent connections: Limited by plan
- Timeout: 5 minutes

### SQL Server Limits
- Max firewall rules: 128 per server
- Max IP addresses per rule: 1 (for JIT)
- Replication points: Automatic, daily
- Connection limit: 32,767 concurrent

### Storage Account Limits
- Max blob size: 4.75 TB
- Max file share size: 100 TB
- Max capacity: Unlimited (pay-as-you-go)

---

## 🔐 Security Reminders

### DO:
- ✅ Keep credentials in environment variables
- ✅ Rotate SQL admin password quarterly
- ✅ Monitor audit logs weekly
- ✅ Use managed identity (not connection strings)
- ✅ Enable monitoring and alerts

### DON'T:
- ❌ Hardcode credentials in code
- ❌ Share function URLs publicly
- ❌ Keep credentials in Git history
- ❌ Use weak passwords
- ❌ Ignore security alerts

---

## 📚 Related Documentation

- **Full Architecture**: See [ARCHITECTURE_DIAGRAM.md](architecture/ARCHITECTURE_DIAGRAM.md)
- **Implementation Details**: See [COMPLIANCE_IMPLEMENTATION.md](implementation/COMPLIANCE_IMPLEMENTATION.md)
- **Deployment Steps**: See [DEPLOYMENT_GUIDE.md](deployment/DEPLOYMENT_GUIDE.md)
- **All Documentation**: See [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)

---

## 🆘 Getting Help

### For Usage Questions
1. Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md) (this file)
2. See [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) for index

### For Deployment Issues
1. See [DEPLOYMENT_GUIDE.md](deployment/DEPLOYMENT_GUIDE.md)
2. Check troubleshooting section above

### For Architecture Questions
1. See [ARCHITECTURE_DIAGRAM.md](architecture/ARCHITECTURE_DIAGRAM.md)
2. Read [COMPLIANCE_IMPLEMENTATION.md](implementation/COMPLIANCE_IMPLEMENTATION.md)

---

## 💡 Pro Tips

**Tip 1**: Save your IP address in a script
```bash
#!/bin/bash
IP=$(curl -s ifconfig.me)
curl -X POST https://YOUR_DOMAIN/api/RequestAccess \
     -H "Content-Type: application/json" \
     -d "{\"ip\": \"$IP\"}"
```

**Tip 2**: Set up a shell alias
```bash
alias request-db-access='curl -X POST https://YOUR_DOMAIN/api/RequestAccess -H "Content-Type: application/json" -d "{\"ip\": \"$(curl -s ifconfig.me)\"}"'
```

**Tip 3**: Create an automation script
```powershell
function Request-DatabaseAccess {
    param([string]$FunctionURL)
    $IP = (curl ifconfig.me).Content.Trim()
    $response = curl -X POST "$FunctionURL/api/RequestAccess" `
      -H "Content-Type: application/json" `
      -d "{`"ip`": `"$IP`"}"
    Write-Host "Access granted until: $($response.expires)"
}
```

