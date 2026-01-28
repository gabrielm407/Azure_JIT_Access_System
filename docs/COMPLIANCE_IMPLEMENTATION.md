# SQL Server Encryption and Compliance Implementation Guide

## Overview

This guide explains the Azure Policy and encryption compliance implementation for your Terraform-managed Azure infrastructure. The implementation ensures encryption is enabled and TDE (Transparent Data Encryption) is active across your SQL Server resources, demonstrating a strong understanding of compliance requirements.

---

## Architecture Components

### 1. **Transparent Data Encryption (TDE)**

#### Service-Managed TDE (Default)
- **File**: `sql_server.tf`
- **Resource**: `azurerm_mssql_server_transparent_data_encryption`
- **Purpose**: Encrypts all data at rest using Azure-managed encryption keys
- **Configuration**:
  ```terraform
  resource "azurerm_mssql_server_transparent_data_encryption" "sql_tde" {
    server_id             = azurerm_mssql_server.sql_server.id
    auto_rotation_enabled = true
  }
  ```

#### Customer-Managed Key (CMK) TDE (Optional)
- **File**: `keyvault.tf`, `sql_server.tf`
- **Feature**: Enable with `var.enable_cmk_encryption = true`
- **Benefit**: Full control over encryption keys stored in Azure Key Vault
- **Security**: Keys are protected and auditable

### 2. **Azure Policy Assignments**

#### File: `azure_policies.tf`

Policy assignments enforce encryption compliance across your subscription:

| Policy | Purpose | Enforcement Mode |
|--------|---------|-----------------|
| `sql_tde_enabled` | Ensures TDE is active | Default (Enforced) |
| `sql_encryption_at_rest` | Validates encryption-at-rest | Default (Enforced) |
| `sql_cmk_encryption` | Audits use of customer-managed keys | Audit (Review-only) |
| `sql_db_encryption` | Audits database encryption status | Default (Enforced) |
| `sql_firewall_rules` | Ensures public network access is denied | Default (Enforced) |
| `sql_encryption_initiative` | Comprehensive SQL encryption initiative | Default (Enforced) |

**Note**: Policy IDs are Azure built-in policies. Change enforcement mode from "Audit" to "Default" after initial validation.

### 3. **Advanced Security Features**

#### Security Alert Policy
- Monitors SQL databases for security threats
- 30-day retention of alerts
- Alerts on suspicious activities
- Email notifications to admins

#### Vulnerability Assessment
- Automated scanning of SQL databases
- Weekly vulnerability scans enabled
- Results stored in blob storage
- Identifies security weaknesses and compliance gaps

#### Auditing
- **Server-level auditing**: Tracks all server activities
- **Database-level auditing**: Tracks database-specific operations
- **Audit actions captured**:
  - Successful/failed authentication
  - Batch execution
  - Schema object access
- **Retention**: 30 days (configurable)
- **Storage**: Encrypted blob storage

### 4. **Key Vault for CMK Management**

#### File: `keyvault.tf`

Features:
- Premium SKU for enhanced security
- Soft delete and purge protection enabled
- Managed identity integration
- Private endpoint access only
- Dedicated private DNS zone

#### Security Controls:
```terraform
resource "azurerm_key_vault" "sql_cmk_vault" {
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false
  # Requires private endpoint for access
}
```

### 5. **Storage Account for Auditing**

#### File: `storage_account.tf`

- **Purpose**: Centralized storage for audit logs and vulnerability assessment reports
- **Encryption**: GRS (Geo-Redundant Storage) for disaster recovery
- **Security**: 
  - HTTPS-only communication
  - TLS 1.2 minimum
  - Private endpoint connectivity
- **Containers**:
  - `sql-audit-logs`: Server and database audit logs
  - `vulnerability-assessments`: Scanning reports

---

## Configuration Variables

### Enable/Disable Features

```terraform
# Enable Customer-Managed Key encryption
enable_cmk_encryption = true

# Configure audit retention
sql_audit_retention_days = 30

# Enable security features
enable_vulnerability_assessment = true
enable_security_alerts = true
enable_auditing = true
```

### Compliance Tags

Add custom compliance tags:
```terraform
compliance_tags = {
  compliance_framework = "Azure Policy"
  encryption_enabled   = "true"
  tde_enabled          = "true"
  audit_enabled        = "true"
}
```

---

## Deployment Steps

### 1. Prerequisites
```bash
# Ensure you have Terraform configured
terraform version  # Should be >= 1.0

# Set environment variables
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Review Plan
```bash
# Audit mode: See what policies will do
terraform plan
```

### 4. Deploy Infrastructure
```bash
# Default: Service-managed TDE
terraform apply

# Or: Enable Customer-Managed Keys
terraform apply -var="enable_cmk_encryption=true"
```

### 5. Verify Compliance
```bash
# Check outputs
terraform output compliance_summary

# In Azure Portal:
# 1. Navigate to SQL Server > Security > Encryption
# 2. Verify TDE is enabled with green checkmark
# 3. Check Auditing > Audit logs enabled
# 4. Review Policy Assignments under Resource Group
```

---

## Compliance Verification Checklist

- [ ] **TDE Enabled**: SQL Server > Transparent Data Encryption shows "Protected by service-managed key" or custom CMK
- [ ] **Audit Enabled**: Server and database audit policies are active
- [ ] **Vulnerability Assessment**: Scheduled scans configured
- [ ] **Security Alerts**: Advanced Data Security is enabled
- [ ] **Network Security**: Private endpoint configured, public access disabled
- [ ] **Azure Policies**: All policy assignments show "Compliant" status
- [ ] **Key Vault**: CMK key exists and rotates automatically
- [ ] **Storage Account**: Audit logs container has data

---

## Key Security Benefits

### ✅ Data Protection
- **At-Rest**: TDE encrypts all database data, backups, and logs
- **In-Transit**: HTTPS/TLS 1.2 enforced
- **Key Management**: Azure Key Vault with RBAC controls

### ✅ Compliance
- **Azure Policy**: Enforces encryption standards automatically
- **Audit Trails**: Complete logging of all database access and changes
- **Vulnerability Management**: Regular scanning identifies weaknesses
- **Retention**: 90-day soft delete protection on keys

### ✅ Monitoring & Alerting
- **Security Alerts**: Threat detection with email notifications
- **Audit Logs**: 30-day retention with GRS backup
- **Policy Compliance**: Dashboard shows enforcement status

---

## Cost Considerations

| Component | Cost Impact |
|-----------|------------|
| TDE (Service-Managed) | Included in SQL Database |
| TDE (Customer-Managed) | Key Vault: ~$6-10/month per key |
| Auditing | SQL Database pricing included |
| Vulnerability Assessment | Advanced Data Security: ~$0.50/DB/day |
| Key Vault Premium | ~$28-35/month |
| Storage Account (GRS) | ~$0.05-0.10/GB/month |
| Azure Policy | No additional cost |

---

## Troubleshooting

### Issue: CMK Key Not Found
```bash
# Verify Key Vault access
az keyvault key list --vault-name <key-vault-name>

# Check SQL Server permissions
az role assignment list --assignee <sql-server-principal-id>
```

### Issue: Policy Not Enforcing
```bash
# Check policy assignment state
az policy assignment list --resource-group <rg-name>

# Verify managed identity has correct permissions
az role assignment list --scope <key-vault-id>
```

### Issue: Auditing Disabled
```bash
# Re-enable auditing
terraform apply -replace="azurerm_mssql_server_audit_policy.sql_audit_policy"
```

---

## Best Practices

1. **Key Rotation**: Enable auto-rotation for CMK (every 90 days recommended)
2. **Access Control**: Use managed identities instead of passwords
3. **Monitoring**: Set up Azure Monitor alerts for policy violations
4. **Backup**: Store audit logs in geo-redundant storage
5. **Compliance**: Review audit logs monthly for compliance reporting
6. **Updates**: Keep Terraform provider updated for latest policy definitions

---

## References

- [Azure SQL Database Encryption](https://docs.microsoft.com/en-us/azure/azure-sql/database/transparent-data-encryption-byok-overview)
- [Azure Policy for SQL](https://docs.microsoft.com/en-us/azure/azure-sql/database/sql-database-audit-policy)
- [Key Vault Security](https://docs.microsoft.com/en-us/azure/key-vault/general/overview)
- [Azure Terraform Provider - SQL Resources](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_server)

---

## Support & Questions

For compliance audits, reference:
- **Framework**: Azure Security Benchmark v2
- **Controls**: SC-7 (Boundary Protection), SC-28 (Data Protection)
- **Evidence**: Terraform state files, Azure Policy compliance reports

