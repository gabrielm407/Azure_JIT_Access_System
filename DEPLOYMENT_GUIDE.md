# SQL Server Encryption & Compliance Deployment Guide

## 🚀 Quick Start

### Prerequisites
```bash
# 1. Ensure Terraform >= 1.0
terraform version

# 2. Set environment variables
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"
$env:ARM_TENANT_ID = "your-tenant-id"
$env:ARM_CLIENT_ID = "your-client-id"
$env:ARM_CLIENT_SECRET = "your-client-secret"

# 3. Verify authentication
az login --service-principal \
  -u $env:ARM_CLIENT_ID \
  -p $env:ARM_CLIENT_SECRET \
  --tenant $env:ARM_TENANT_ID
```

### Deploy in 3 Steps

```bash
# Step 1: Initialize
terraform init

# Step 2: Review plan
terraform plan

# Step 3: Apply
terraform apply
```

---

## 📋 What Gets Deployed

### Core Resources
- ✅ Azure SQL Server (private endpoint, no public access)
- ✅ SQL Database with TDE
- ✅ Key Vault (for Customer-Managed Keys)
- ✅ Storage Account (for audit logs)
- ✅ Private Endpoints (SQL + Key Vault)
- ✅ Private DNS Zones

### Compliance & Security
- ✅ 6 Azure Policy assignments
- ✅ Server-level auditing
- ✅ Vulnerability assessment (auto-scan)
- ✅ Security alerts
- ✅ TDE (auto-rotation enabled)

---

## 🔧 Configuration Options

### Option 1: Minimal (Service-Managed Encryption)
```bash
terraform apply
```
**Cost**: Included in SQL Database pricing
**Features**: TDE enabled, auditing, vulnerability scans

### Option 2: Enhanced (Customer-Managed Keys)
```bash
terraform apply -var="enable_cmk_encryption=true"
```
**Cost**: +$28/month (Key Vault)
**Features**: All of Option 1 + CMK encryption, key rotation

### Option 3: Stricter Audit Retention
```bash
terraform apply \
  -var="sql_audit_retention_days=365" \
  -var="enable_cmk_encryption=true"
```
**Cost**: +$28/month (Key Vault) + storage for logs
**Benefit**: 1-year audit trail for compliance

---

## ✅ Verification Checklist

After deployment, verify:

### 1. Check TDE Status
```bash
terraform output tde_status
# Expected: tde is enabled
```

### 2. Verify Audit Storage
```bash
terraform output sql_audit_storage_account_name
# Then check in Azure Portal > Storage Account > Containers
```

### 3. Confirm Policy Assignments
```bash
terraform output azure_policy_assignments
# Expected: 5 policy assignments listed
```

### 4. Check Compliance Summary
```bash
terraform output compliance_summary
```

### 5. Azure Portal Verification
1. Navigate to SQL Server > Security > Encryption
   - Expect: TDE enabled (green checkmark)
   
2. SQL Server > Security > Advanced Data Security
   - Expect: Enabled
   
3. SQL Server > Auditing
   - Expect: Enabled, pointing to storage account
   
4. Policy > Assignments
   - Filter by "sql-" 
   - Expect: 5+ assignments in "Compliant" state

---

## 🔐 Security Configurations Explained

### What's Protected?

| Component | Encryption | Location | Rotation |
|-----------|-----------|----------|----------|
| Data at Rest | TDE (AES-256) | SQL Database | Auto (CMK) |
| Backups | TDE | Geo-Redundant | Auto |
| Keys | RSA-2048 | Key Vault | 90 days (auto) |
| Audit Logs | Storage Encryption | GRS Storage | N/A |
| Network Traffic | HTTPS/TLS 1.2 | All | Built-in |

### Network Isolation

- **SQL Server**: Private endpoint only (no internet)
- **Key Vault**: Private endpoint only (no internet)
- **Access Method**: Through VNet/private connectivity
- **Public Access**: Explicitly denied

---

## 🚨 Common Issues & Solutions

### Issue: "Policy Definition Not Found"
```bash
# Some policy IDs may vary by region
# Solution: Update policy IDs in azure_policies.tf with your region's policies
# or change to Audit mode first to see what works
```

### Issue: "Key Vault Access Denied"
```bash
# The SQL Server's managed identity needs Key Vault access
# Terraform handles this with azurerm_role_assignment
# If it fails, manually grant permissions:

az role assignment create \
  --role "Key Vault Crypto Service Encryption User" \
  --assignee-object-id <sql-managed-identity-id> \
  --assignee-principal-type ServicePrincipal \
  --scope <key-vault-id>
```

### Issue: "CMK Key Not Found"
```bash
# Ensure var.enable_cmk_encryption is set correctly
terraform apply -var="enable_cmk_encryption=true" -target=azurerm_key_vault_key.sql_cmk_key
```

### Issue: "Audit Logs Not Appearing"
```bash
# Check storage account container exists
az storage container list --account-name <storage-account-name>

# If missing, recreate:
terraform destroy -target=azurerm_storage_container.sql_audit_logs
terraform apply -target=azurerm_storage_container.sql_audit_logs
```

---

## 📊 Cost Estimation

### Minimal Deployment (Service-Managed TDE)
| Service | Cost |
|---------|------|
| SQL Database (S0) | ~$15/month |
| Storage Account (GRS) | ~$10/month |
| Private Endpoints (2) | ~$0.50/month |
| Azure Policy | Free |
| **Total** | **~$25/month** |

### Enhanced Deployment (CMK)
| Service | Cost |
|---------|------|
| SQL Database (S0) | ~$15/month |
| Storage Account (GRS) | ~$10/month |
| Key Vault (Premium) | ~$28/month |
| Private Endpoints (3) | ~$0.75/month |
| Azure Policy | Free |
| **Total** | **~$54/month** |

### High-Volume Audit (1-year retention)
Add ~$0.50-2/month for audit log storage depending on activity

---

## 🔄 Deployment Variations

### Development Environment
```bash
terraform apply \
  -var="enable_cmk_encryption=false" \
  -var="sql_audit_retention_days=30" \
  -var="enable_vulnerability_assessment=false"
```

### Staging Environment
```bash
terraform apply \
  -var="enable_cmk_encryption=true" \
  -var="sql_audit_retention_days=90" \
  -var="enable_vulnerability_assessment=true"
```

### Production Environment
```bash
terraform apply \
  -var="enable_cmk_encryption=true" \
  -var="sql_audit_retention_days=365" \
  -var="enable_vulnerability_assessment=true"
```

---

## 🔑 Key Outputs After Deployment

```bash
# View all outputs
terraform output

# Specific outputs:
terraform output compliance_summary      # Overall compliance status
terraform output tde_status             # TDE configuration
terraform output cmk_key_id             # CMK key ID (if enabled)
terraform output keyvault_id            # Key Vault ID
terraform output azure_policy_assignments  # Policy details
```

---

## 📝 Terraform Backend Configuration

### Option 1: Terraform Cloud (Recommended)
```hcl
# Already configured in providers.tf
# Login: terraform login
# Then: terraform apply
```

### Option 2: Azure Storage Account
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "your-rg"
    storage_account_name = "yourstorageacct"
    container_name       = "tfstate"
    key                  = "sql-encryption.tfstate"
  }
}
```

### Option 3: Local State (Development Only)
```bash
# Keep terraform.tfstate in .gitignore
echo "terraform.tfstate*" >> .gitignore
```

---

## 🔐 Securing Sensitive Data

### Protect Credentials
```bash
# Use environment variables
$env:TF_VAR_sql_admin_username = "admin"
$env:TF_VAR_sql_admin_password = "SecurePassword123!"

# Or use a .tfvars file (add to .gitignore)
cat > terraform.tfvars << EOF
sql_admin_username = "admin"
sql_admin_password = "SecurePassword123!"
EOF

# Never commit credentials
echo "terraform.tfvars" >> .gitignore
```

---

## 📚 Additional Resources

- [COMPLIANCE_IMPLEMENTATION.md](COMPLIANCE_IMPLEMENTATION.md) - Detailed implementation guide
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Quick code snippets
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - What was implemented

---

## ✨ Next Steps

1. **Deploy**: Run `terraform apply`
2. **Monitor**: Check `terraform output compliance_summary`
3. **Test**: Query SQL Server using private endpoint
4. **Audit**: Review logs in storage account
5. **Compliance**: Submit outputs for compliance audit

---

## 💡 Pro Tips

1. **Start with Audit**: Use non-enforcing policies initially
2. **Monitor Costs**: Enable CMK only if required
3. **Test Backups**: Ensure encrypted backups work
4. **Review Logs**: Check audit logs weekly
5. **Key Rotation**: Enable auto-rotation for CMK
6. **DR Plan**: Document disaster recovery procedures

---

## 🆘 Getting Help

If something goes wrong:

1. Check terraform state: `terraform show`
2. Review resource details: `terraform state show azurerm_mssql_server.sql_server`
3. Check Azure Portal for manual verification
4. Review error messages in policy assignments
5. Check Key Vault access policies

---

## ✅ Deployment Complete!

Your SQL Server is now:
- ✅ Encrypted at rest (TDE)
- ✅ Audited (30-day retention)
- ✅ Secured (private endpoint, no public access)
- ✅ Compliant (Azure Policy enforced)
- ✅ Monitored (vulnerability scans, alerts)
- ✅ Documented (comprehensive compliance guide)

**Next**: Commit to Git and follow your deployment pipeline.

