# Azure Policy & Encryption Quick Reference

## 🔐 Encryption Implementation Summary

### TDE Configuration
```hcl
# Service-Managed TDE (Automatic)
resource "azurerm_mssql_server_transparent_data_encryption" "sql_tde" {
  server_id            = azurerm_mssql_server.sql_server.id
  auto_rotation_enabled = true  # Automatic key rotation
}
```

### Customer-Managed Keys (CMK)
```hcl
# Enable via variable
enable_cmk_encryption = true

# Key stored in Azure Key Vault
resource "azurerm_key_vault_key" "sql_cmk_key" {
  name         = "sql-tde-key"
  key_vault_id = azurerm_key_vault.sql_cmk_vault.id
  key_type     = "RSA"
  key_size     = 2048
}
```

---

## 📋 Azure Policy Assignments

### 1. TDE Enforcement Policy
```hcl
resource "azurerm_subscription_policy_assignment" "sql_tde_enabled" {
  name                 = "enforce-sql-tde-enabled"
  subscription_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}"
  policy_definition_id = "/subscriptions/.../policyDefinitions/17k78e20-9358-41c9-923c-fb736d3e48ce"
  enforcement_mode     = "Default"  # Change to "Audit" for review mode
}
```

**Effect**: Denies SQL databases without TDE enabled

### 2. Encryption-at-Rest Policy
```hcl
resource "azurerm_subscription_policy_assignment" "sql_encryption_at_rest" {
  enforcement_mode = "Default"
}
```

**Effect**: Ensures all data is encrypted when stored

### 3. CMK Encryption Audit Policy
```hcl
resource "azurerm_subscription_policy_assignment" "sql_cmk_encryption" {
  enforcement_mode = "Audit"  # Review only, doesn't deny
}
```

**Effect**: Identifies resources not using customer-managed keys

### 4. Public Network Access Policy
```hcl
resource "azurerm_subscription_policy_assignment" "sql_firewall_rules" {
  enforcement_mode = "Default"
}
```

**Effect**: Denies public network access to SQL servers

---

## 🔑 Key Vault Setup for CMK

### Create Key Vault
```hcl
resource "azurerm_key_vault" "sql_cmk_vault" {
  name                      = "sqlcmk-vault"
  sku_name                  = "premium"
  purge_protection_enabled  = true
  soft_delete_retention_days = 90
  public_network_access_enabled = false
  
  # Require private endpoint for access
}
```

### Grant SQL Server Access
```hcl
resource "azurerm_key_vault_access_policy" "sql_server_policy" {
  key_vault_id = azurerm_key_vault.sql_cmk_vault.id
  object_id    = azurerm_mssql_server.sql_server.identity[0].principal_id
  
  key_permissions = [
    "Get", "List", "UnwrapKey", "WrapKey",
    "Sign", "Verify", "Create", "Update", "Delete"
  ]
}
```

---

## 📊 Auditing & Compliance

### Server-Level Auditing
```hcl
resource "azurerm_mssql_server_audit_policy" "sql_audit_policy" {
  server_id                       = azurerm_mssql_server.sql_server.id
  enabled                         = true
  storage_endpoint                = azurerm_storage_account.sql_audit_storage.primary_blob_endpoint
  storage_account_access_key      = azurerm_storage_account.sql_audit_storage.primary_access_key
  retention_in_days               = 30
  
  audit_actions_and_groups = [
    "SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP",
    "FAILED_DATABASE_AUTHENTICATION_GROUP",
    "BATCH_COMPLETED_GROUP",
    "SCHEMA_OBJECT_ACCESS_GROUP"
  ]
}
```

### Database-Level Auditing
```hcl
resource "azurerm_mssql_database_extended_auditing_policy" "sql_db_audit" {
  database_id                = azurerm_mssql_database.sql_database.id
  enabled                    = true
  storage_endpoint           = azurerm_storage_account.sql_audit_storage.primary_blob_endpoint
  retention_in_days          = 30
}
```

### Security Alerts
```hcl
resource "azurerm_mssql_server_security_alert_policy" "sql_security_alerts" {
  resource_group_name       = var.resource_group_name
  server_name               = azurerm_mssql_server.sql_server.name
  state                     = "Enabled"
  retention_days            = 30
  email_notification_admins = true
}
```

---

## 🛡️ Network Security

### Private Endpoint (No Public Access)
```hcl
resource "azurerm_private_endpoint" "sql_private_endpoint" {
  subnet_id = module.virtual_network.subnet_id
  
  private_service_connection {
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}
```

### Private DNS Zone
```hcl
resource "azurerm_private_dns_zone" "sql_dns" {
  name = "privatelink.database.windows.net"
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_vnet_link" {
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = module.virtual_network.id
}
```

---

## 🚀 Deployment Examples

### Basic Deployment (Service-Managed TDE)
```bash
terraform init
terraform plan
terraform apply
```

### With Customer-Managed Keys
```bash
terraform apply \
  -var="enable_cmk_encryption=true" \
  -var="sql_audit_retention_days=90"
```

### Audit Mode (No Enforcement)
```bash
# First, set all policies to "Audit" mode
# Review compliance status without blocking changes
terraform apply

# Then enable enforcement
terraform apply -var="enforcement_mode=Default"
```

---

## ✅ Verification Commands

### Check TDE Status
```bash
# Terraform output
terraform output tde_status

# Or in Azure Portal:
# SQL Server > Security > Transparent Data Encryption
# Should show: "Protected by service-managed key" or custom CMK
```

### Verify Audit Logs
```bash
# Check storage account
az storage blob list \
  --container-name sql-audit-logs \
  --account-name <storage-account>
```

### View Policy Compliance
```bash
# List policy assignments
terraform output azure_policy_assignments

# Check compliance in Azure Portal:
# Policy > Assignments > Filter by "sql-"
```

### Validate CMK Configuration
```bash
# List Key Vault keys
terraform output cmk_key_id

# Check access policy
az keyvault access-policy list --vault-name <vault-name>
```

---

## 📈 Compliance Checklist

- [ ] TDE enabled on SQL Server
- [ ] Encryption at rest configured
- [ ] Public network access disabled
- [ ] Private endpoint configured
- [ ] Auditing enabled (server + database level)
- [ ] Vulnerability assessment scheduled
- [ ] Security alerts configured
- [ ] Azure Policy assignments created
- [ ] CMK keys rotated (if using CMK)
- [ ] Audit logs retained for 30+ days

---

## 🔄 Enforcement Modes Explained

| Mode | Effect | Use Case |
|------|--------|----------|
| `Default` | **Enforces** policy - denies non-compliant resources | Production, strict compliance |
| `Audit` | **Reports only** - allows non-compliant resources | Initial assessment, monitoring |
| `Disabled` | No enforcement | Troubleshooting |

---

## 💡 Pro Tips

1. **Start with Audit**: Use Audit mode first to understand compliance gaps
2. **Gradual Rollout**: Move policies to Default mode after team adjustment
3. **Monitor Regularly**: Check Azure Policy dashboard monthly
4. **Key Rotation**: Enable auto-rotation for CMK keys
5. **Cost Optimization**: Use service-managed TDE unless CMK required for compliance

---

## Common Issues & Solutions

### Issue: "CMK key not authorized"
```bash
# Ensure SQL Server managed identity has access
az role assignment create \
  --role "Key Vault Crypto Service Encryption User" \
  --assignee <sql-server-principal-id> \
  --scope <key-vault-id>
```

### Issue: "Policy assignment failed"
```bash
# Verify subscription permissions
az policy assignment create \
  --name enforce-tde \
  --display-name "Enforce TDE" \
  --policy-definition-id <policy-id>
```

### Issue: "Audit logs not appearing"
```bash
# Re-enable audit policy
terraform destroy -target=azurerm_mssql_server_audit_policy.sql_audit_policy
terraform apply -target=azurerm_mssql_server_audit_policy.sql_audit_policy
```

