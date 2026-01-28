# Azure SQL Server Encryption & Compliance Architecture Diagram

## Complete Resource Architecture

```mermaid
graph TB
    subgraph "Azure Subscription"
        subgraph "Resource Group"
            RG["Resource Group<br/>(my-resourcegroup-dev)"]
        end
        
        subgraph "Virtual Network"
            VNET["Virtual Network<br/>(10.0.0.0/16)"]
            SUBNET["Subnet<br/>(Private)"]
        end
        
        subgraph "SQL Server & Database"
            SQLSRV["Azure SQL Server<br/>(Service-Managed/CMK)<br/>⚡ Cost: $15/mo"]
            SQLDB["SQL Database<br/>(Encrypted with TDE)<br/>sentineldb"]
            MANAGED_ID["Managed Identity<br/>(SystemAssigned)"]
        end
        
        subgraph "Key Vault (Optional CMK)"
            KEYVAULT["Azure Key Vault<br/>(Premium SKU)<br/>⚡ Cost: $28/mo<br/>if enabled"]
            CMK_KEY["CMK Key<br/>(RSA-2048)"]
            SOFT_DELETE["Soft Delete<br/>(90 days)"]
        end
        
        subgraph "Storage & Auditing"
            STORAGE["Storage Account<br/>(GRS)<br/>⚡ Cost: $10/mo"]
            AUDIT_LOGS["Audit Logs<br/>Container"]
            VULN_REPORTS["Vulnerability<br/>Reports Container"]
        end
        
        subgraph "Network Security"
            SQLPE["SQL Private Endpoint<br/>⚡ Cost: $0.35/mo"]
            KVPE["Key Vault Private Endpoint<br/>⚡ Cost: $0.35/mo"]
            SQLDNS["Private DNS Zone<br/>(database.windows.net)<br/>Free"]
            KVDNS["Private DNS Zone<br/>(vaultcore.azure.net)<br/>Free"]
        end
        
        subgraph "Azure Policy & Compliance"
            POLICIES["Azure Policy Assignments<br/>Free"]
            P1["TDE Enforcement"]
            P2["Encryption at Rest"]
            P3["CMK Auditing"]
            P4["DB Encryption Check"]
            P5["Firewall Rules"]
            P6["Initiative"]
        end
        
        subgraph "Security & Monitoring"
            AUDIT["Server Auditing<br/>(Extended)"]
            VULN_SCAN["Vulnerability<br/>Assessment<br/>(Weekly)"]
            ALERTS["Security Alerts<br/>(Real-time)"]
        end
    end
    
    %% SQL Server Connections
    SQLSRV -->|encrypted with| SQLDB
    SQLSRV -->|uses| MANAGED_ID
    MANAGED_ID -->|accesses| CMK_KEY
    SQLDB -->|encrypted by| CMK_KEY
    SQLSRV -->|writes to| AUDIT_LOGS
    SQLDB -->|audited by| AUDIT
    
    %% Network Connectivity
    SUBNET -->|connects to| SQLPE
    SUBNET -->|connects to| KVPE
    SQLPE -->|resolves via| SQLDNS
    KVPE -->|resolves via| KVDNS
    SQLPE -->|accesses| SQLSRV
    KVPE -->|accesses| KEYVAULT
    
    %% Key Vault Setup
    KEYVAULT -->|stores| CMK_KEY
    KEYVAULT -->|protects| SOFT_DELETE
    KEYVAULT -->|requires| MANAGED_ID
    
    %% Storage Connections
    SQLSRV -->|logs to| STORAGE
    AUDIT -->|writes to| AUDIT_LOGS
    VULN_SCAN -->|reports to| VULN_REPORTS
    STORAGE -->|contains| AUDIT_LOGS
    STORAGE -->|contains| VULN_REPORTS
    
    %% Policy Connections
    POLICIES -->|enforces| P1
    POLICIES -->|enforces| P2
    POLICIES -->|enforces| P3
    POLICIES -->|enforces| P4
    POLICIES -->|enforces| P5
    POLICIES -->|enforces| P6
    P1 -->|requires| SQLDB
    P2 -->|requires| KEYVAULT
    P5 -->|requires| SQLPE
    
    %% Monitoring
    SQLSRV -->|monitored by| AUDIT
    SQLDB -->|scanned by| VULN_SCAN
    SQLDB -->|alerted by| ALERTS
    ALERTS -->|notifies| AUDIT_LOGS
    
    %% Resource Group Association
    RG -->|contains| SQLSRV
    RG -->|contains| KEYVAULT
    RG -->|contains| STORAGE
    RG -->|contains| VNET
    
    style SQLSRV fill:#ff9999
    style KEYVAULT fill:#ffcc99
    style STORAGE fill:#99ccff
    style SQLPE fill:#99ff99
    style KVPE fill:#99ff99
    style POLICIES fill:#ffff99
    style AUDIT fill:#ff99ff
    style VULN_SCAN fill:#ff99ff
    style ALERTS fill:#ff99ff
```

---

## Data Flow Diagram

```mermaid
graph LR
    USER["User/Application<br/>(VNet)"]
    
    USER -->|encrypted connection| SQLPE
    SQLPE -->|private link| SQLSRV
    SQLSRV -->|query request| SQLDB
    
    SQLDB -->|encrypted data| SQLSRV
    SQLSRV -->|audit event| AUDIT_LOG["Audit Storage"]
    
    KEYVAULT["Key Vault"]
    CMK["CMK Key"]
    
    SQLSRV -->|request key| KEYVAULT
    KEYVAULT -->|return key| CMK
    CMK -->|decrypt data| SQLDB
    SQLDB -->|encrypted data| USER
    
    POLICIES["Azure Policies"]
    MONITOR["Monitoring & Alerts"]
    
    POLICIES -.->|enforce| SQLSRV
    SQLDB -.->|monitored by| MONITOR
    MONITOR -.->|alert on| AUDIT_LOG
    
    style USER fill:#e1f5ff
    style SQLPE fill:#c8e6c9
    style SQLSRV fill:#ffcdd2
    style SQLDB fill:#ffcdd2
    style KEYVAULT fill:#fff9c4
    style CMK fill:#fff9c4
    style POLICIES fill:#f0f4c3
    style MONITOR fill:#f8bbd0
```

---

## Network Isolation Architecture

```mermaid
graph TB
    INTERNET["❌ Internet<br/>(Blocked)"]
    
    subgraph VNET["Azure VNet<br/>(10.0.0.0/16)"]
        SUBNET["Private Subnet"]
        APP["Your Application<br/>(Private)"]
    end
    
    subgraph PRIVATE_SQL["SQL Server<br/>(Private)"]
        SQLPE["Private Endpoint<br/>⚠️ Cost: $0.35/mo"]
        SQLSRV["SQL Server<br/>No Public IP<br/>⚠️ Cost: $15/mo"]
    end
    
    subgraph PRIVATE_KV["Key Vault<br/>(Private)"]
        KVPE["Private Endpoint<br/>⚠️ Cost: $0.35/mo"]
        KEYVAULT["Key Vault<br/>No Public IP<br/>⚠️ Cost: $28/mo"]
    end
    
    subgraph PRIVATE_STORAGE["Storage<br/>(Private)"]
        STORAGE["Storage Account<br/>HTTPS Only<br/>⚠️ Cost: $10/mo"]
    end
    
    INTERNET -->|❌ DENIED| SQLPE
    INTERNET -->|❌ DENIED| KVPE
    INTERNET -->|❌ DENIED| STORAGE
    
    APP -->|✅ Private Link| SQLPE
    SQLPE -->|Private Connection| SQLSRV
    
    APP -->|✅ Private Link| KVPE
    KVPE -->|Private Connection| KEYVAULT
    
    SQLSRV -->|✅ Service Access| STORAGE
    KEYVAULT -->|Managed Identity| SQLSRV
    
    SUBNET -->|DNS Resolution| PDNS1["Private DNS<br/>privatelink.database.windows.net<br/>Free"]
    SUBNET -->|DNS Resolution| PDNS2["Private DNS<br/>privatelink.vaultcore.azure.net<br/>Free"]
    
    style INTERNET fill:#ffcdd2
    style SQLPE fill:#c8e6c9
    style KVPE fill:#c8e6c9
    style SQLSRV fill:#ffcdd2
    style KEYVAULT fill:#fff9c4
    style STORAGE fill:#bbdefb
    style APP fill:#c8e6c9
    style PDNS1 fill:#e1bee7
    style PDNS2 fill:#e1bee7
```

---

## Encryption Layers

```mermaid
graph TB
    subgraph "Data Protection Layers"
        L1["Layer 1: Network<br/>━━━━━━━━━━━━━<br/>Private Endpoints<br/>No Public Access<br/>HTTPS/TLS 1.2 Minimum"]
        
        L2["Layer 2: Data at Rest<br/>━━━━━━━━━━━━━<br/>TDE Encryption<br/>AES-256<br/>Service-Managed or CMK"]
        
        L3["Layer 3: Key Management<br/>━━━━━━━━━━━━━<br/>Azure Key Vault<br/>Premium SKU<br/>Soft Delete 90 days"]
        
        L4["Layer 4: Auditing<br/>━━━━━━━━━━━━━<br/>Server Auditing<br/>Database Auditing<br/>Retention 30+ days"]
        
        L5["Layer 5: Monitoring<br/>━━━━━━━━━━━━━<br/>Vulnerability Scans<br/>Security Alerts<br/>Azure Policies"]
    end
    
    L1 --> L2
    L2 --> L3
    L3 --> L4
    L4 --> L5
    
    style L1 fill:#bbdefb
    style L2 fill:#ffcdd2
    style L3 fill:#fff9c4
    style L4 fill:#f8bbd0
    style L5 fill:#c8e6c9
```

---

## Cost Analysis: Resource Dependencies

```mermaid
graph TD
    subgraph "Always-On Costs"
        SQL["SQL Server<br/>$15/month<br/>🔴 ALWAYS CREATED"]
        STORAGE["Storage Account<br/>$10/month<br/>🔴 ALWAYS CREATED"]
        PE1["Private Endpoint SQL<br/>$0.35/month<br/>🔴 ALWAYS CREATED"]
    end
    
    subgraph "Conditional Costs"
        KEYVAULT["Key Vault<br/>$28/month<br/>🟡 ONLY IF CMK ENABLED"]
        PE2["Private Endpoint KV<br/>$0.35/month<br/>🟡 ONLY IF CMK ENABLED"]
    end
    
    subgraph "Zero-Cost Resources"
        POLICIES["Azure Policies<br/>$0/month<br/>✅ FREE"]
        PDNS["Private DNS<br/>$0/month<br/>✅ FREE"]
        MANAGED_ID["Managed Identity<br/>$0/month<br/>✅ FREE"]
        AUDIT["Auditing<br/>$0/month<br/>✅ FREE"]
        VULN["Vulnerability Scan<br/>$0/month<br/>✅ FREE"]
    end
    
    TOTAL1["Total Without CMK<br/>$25.70/month"]
    TOTAL2["Total With CMK<br/>$54.00/month"]
    
    SQL --> TOTAL1
    STORAGE --> TOTAL1
    PE1 --> TOTAL1
    
    SQL --> TOTAL2
    STORAGE --> TOTAL2
    PE1 --> TOTAL2
    KEYVAULT --> TOTAL2
    PE2 --> TOTAL2
    
    style SQL fill:#ff9999
    style STORAGE fill:#ff9999
    style PE1 fill:#ff9999
    style KEYVAULT fill:#ffcc99
    style PE2 fill:#ffcc99
    style POLICIES fill:#99ff99
    style PDNS fill:#99ff99
    style MANAGED_ID fill:#99ff99
    style AUDIT fill:#99ff99
    style VULN fill:#99ff99
    style TOTAL1 fill:#ffe0b2
    style TOTAL2 fill:#ffe0b2
```

---

## Deployment Sequence

```mermaid
sequenceDiagram
    participant Terraform
    participant RG as Resource Group
    participant VNET as Virtual Network
    participant SQL as SQL Server
    participant STORAGE as Storage Account
    participant KV as Key Vault
    participant POLICY as Azure Policy

    Terraform->>RG: Create Resource Group
    Terraform->>VNET: Create Virtual Network & Subnet
    Terraform->>SQL: Create SQL Server (Managed Identity)
    Terraform->>SQL: Create SQL Database
    Terraform->>STORAGE: Create Storage Account (GRS)
    Terraform->>STORAGE: Create Audit Containers
    Terraform->>SQL: Enable TDE
    Terraform->>SQL: Create Private Endpoint
    
    alt if enable_cmk_encryption = true
        Terraform->>KV: Create Key Vault (Premium)
        Terraform->>KV: Create CMK Key
        Terraform->>SQL: Link SQL to CMK
        Terraform->>KV: Create Private Endpoint
    else
        Note over KV: ⚠️ Key Vault still created!
    end
    
    Terraform->>POLICY: Assign TDE Policy
    Terraform->>POLICY: Assign Encryption Policies
    Terraform->>POLICY: Assign Firewall Policy
    
    SQL->>STORAGE: Configure Audit Logging
    SQL->>STORAGE: Configure Vulnerability Assessment
```

---

## How to View These Diagrams

### Option 1: GitHub (Automatically Renders)
If you push this file to GitHub, Mermaid diagrams render automatically in the README.

### Option 2: Online Editor
Paste any diagram code into: https://mermaid.live

### Option 3: VS Code Extension
Install "Markdown Preview Mermaid Support" extension:
- Cmd: `ext install markdown-mermaid`
- View in preview pane (Ctrl+Shift+V)

### Option 4: Convert to PNG/SVG
```bash
npm install -g mermaid-cli
mmdc -i ARCHITECTURE_DIAGRAM.md -o architecture.png
```

---

## Resource Summary Table

| Resource | Type | Cost/Month | Always Created? | Purpose |
|----------|------|-----------|---|---------|
| SQL Server | azurerm_mssql_server | $15 | ✅ Yes | Database engine |
| SQL Database | azurerm_mssql_database | Included | ✅ Yes | Data storage |
| Storage Account | azurerm_storage_account | $10 | ✅ Yes | Audit logs, reports |
| Key Vault | azurerm_key_vault | $28 | 🟡 CMK only | CMK storage |
| Private Endpoint (SQL) | azurerm_private_endpoint | $0.35 | ✅ Yes | Secure SQL access |
| Private Endpoint (KV) | azurerm_private_endpoint | $0.35 | 🟡 CMK only | Secure KV access |
| Private DNS Zone (SQL) | azurerm_private_dns_zone | FREE | ✅ Yes | DNS resolution |
| Private DNS Zone (KV) | azurerm_private_dns_zone | FREE | 🟡 CMK only | DNS resolution |
| Managed Identity | SystemAssigned | FREE | ✅ Yes | SQL authentication |
| Azure Policies | subscription_policy_assignment | FREE | ✅ Yes | Compliance enforcement |
| Auditing | extended_auditing_policy | FREE | ✅ Yes | Logging |
| Vulnerability Assessment | vulnerability_assessment | FREE | ✅ Yes | Security scans |
| Security Alerts | (via auditing) | FREE | ✅ Yes | Threat detection |

---

## Key Insights

### 🔴 Cost Reality Check
- **Minimum Cost**: $25.70/month (without CMK)
- **Full Cost**: $54.00/month (with CMK)
- **These costs are ALWAYS charged**, even if resources sit idle

### 🟡 Key Vault Problem
- **Always created** even when `enable_cmk_encryption = false`
- **Charges $28/month** whether used or not
- **Solution**: Wrap Key Vault in a conditional (`count` variable)

### ✅ No Hidden Costs
- Azure Policies: Free
- Private DNS: Free  
- Managed Identity: Free
- Auditing: Free
- Vulnerability Scans: Free

### 🎯 Optimization Recommendations
1. **For non-production**: Skip CMK (`enable_cmk_encryption = false`)
2. **For development**: Destroy when not in use
3. **For production**: Accept the cost for compliance

