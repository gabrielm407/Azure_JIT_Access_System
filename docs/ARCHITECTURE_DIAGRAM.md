# Azure JIT Access System - Architecture Diagram

## Complete Resource Architecture

```mermaid
graph TB
    subgraph "Azure Subscription"
        subgraph "Resource Group"
            RG["Resource Group<br/>(my-resource-group)"]
        end
        
        subgraph "Virtual Network & Networking"
            VNET["Virtual Network<br/>(10.0.0.0/16)"]
            SUBNET["Subnet<br/>(Private)"]
            NSG["Network Security Group"]
        end
        
        subgraph "SQL Server & Database"
            SQLSRV["Azure SQL Server<br/>(Private Access Only)<br/>⚡ Cost: $15/mo"]
            SQLDB["SQL Database<br/>(TDE Encrypted)<br/>sentineldb"]
            MANAGED_ID["Managed Identity<br/>(SystemAssigned)"]
            FIREWALL["Dynamic Firewall<br/>(JIT Rules)"]
        end
        
        subgraph "Azure Functions (JIT Access Engine)"
            FUNC["Azure Function<br/>(RequestAccess)<br/>.NET 8 Isolated<br/>⚡ Serverless"]
            FUNCID["Function Managed ID<br/>(For SQL Access)"]
        end
        
        subgraph "API Gateway & Auth"
            APIGW["API Endpoint<br/>(curl -X POST)"]
            AUTH["Authentication<br/>(Service Principal)"]
            VALIDATE["Request Validation<br/>(IP, Duration)"]
        end
        
        subgraph "Storage & Logging"
            STORAGE["Storage Account<br/>(Audit Logs)<br/>⚡ Cost: $10/mo"]
            LOGS["JIT Access Logs<br/>Container"]
        end
        
        subgraph "Network Security (Private Access)"
            SQLPE["SQL Private Endpoint<br/>⚡ Cost: $0.35/mo"]
            SQLDNS["Private DNS Zone<br/>(database.windows.net)<br/>Free"]
        end
        
        subgraph "Monitoring & Observability"
            INSIGHTS["Application Insights<br/>Monitoring"]
            ALERTS["JIT Activity Alerts"]
            DASHBOARD["Compliance Dashboard"]
        end
    end
    
    %% JIT Flow
    USER["👤 Developer<br/>(External)"]
    USER -->|POST /api/RequestAccess| APIGW
    APIGW -->|authenticate| AUTH
    AUTH -->|validate request| VALIDATE
    VALIDATE -->|get SQL permission| FUNC
    FUNC -->|invoke| FUNCID
    FUNCID -->|create firewall rule| FIREWALL
    FIREWALL -->|opens access for IP<br/>1 hour TTL| SQLSRV
    
    %% SQL Server Connections
    SQLSRV -->|encrypted| SQLDB
    SQLSRV -->|uses| MANAGED_ID
    SQLDB -->|TDE encrypted| USER
    SQLSRV -->|logs JIT event| LOGS
    
    %% Network Connectivity
    SUBNET -->|contains| FUNC
    SUBNET -->|connects to| SQLPE
    SQLPE -->|resolves via| SQLDNS
    SQLPE -->|accesses| SQLSRV
    
    %% Storage & Logging
    FUNC -->|writes| LOGS
    LOGS -->|audit trail| STORAGE
    
    %% Monitoring
    FUNC -->|telemetry| INSIGHTS
    INSIGHTS -->|detects anomalies| ALERTS
    ALERTS -->|displays| DASHBOARD
    SQLSRV -->|monitored by| INSIGHTS
    
    %% Resource Group Association
    RG -->|contains| SQLSRV
    RG -->|contains| FUNC
    RG -->|contains| STORAGE
    RG -->|contains| VNET
    
    style USER fill:#90EE90
    style FUNC fill:#87CEEB
    style APIGW fill:#FFB6C1
    style SQLSRV fill:#FFB347
    style FIREWALL fill:#FFFF99
    style STORAGE fill:#DDA0DD
    style SQLPE fill:#98FB98
    style INSIGHTS fill:#F0E68C
    style ALERTS fill:#FFB6B6
    style DASHBOARD fill:#E0FFFF
```

---

## Data Flow Diagram (JIT Access Request)

```mermaid
graph LR
    USER["👤 Developer/User"]
    
    USER -->|1. POST /api/RequestAccess| API["Azure Function<br/>(RequestAccess)"]
    
    API -->|2. Authenticate| MSI["Managed Identity<br/>(Service Principal)"]
    API -->|3. Validate IP| VAL["Validation Engine<br/>(Check IP format)"]
    VAL -->|4. Approved| RULE["Create Firewall Rule<br/>(IP-specific)"]
    
    RULE -->|5. Add to SQL| SQLSRV["Azure SQL Server<br/>(Firewall)"]
    SQLSRV -->|6. Grant Access| SQLDB["SQL Database<br/>(1 Hour TTL)"]
    
    API -->|7. Log Activity| LOGS["Storage Account<br/>(Audit Trail)"]
    API -->|8. Return Details| USER
    
    USER -->|9. Connect| SQLDB
    SQLDB -->|10. Encrypted Data| USER
    
    SCHEDULER["Auto-Cleanup Timer<br/>(Every 5 min)"] -.->|11. Check Expiry| RULE
    RULE -.->|12. Remove Expired| SQLSRV
    
    INSIGHTS["Application Insights"] -.->|Monitors| API
    INSIGHTS -.->|Logs| LOGS
    
    style USER fill:#90EE90
    style API fill:#87CEEB
    style SQLSRV fill:#FFB347
    style SQLDB fill:#FFB6C1
    style LOGS fill:#DDA0DD
    style INSIGHTS fill:#F0E68C
    style SCHEDULER fill:#FFB347
```

---

## JIT Access Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    JIT ACCESS REQUEST FLOW                      │
└─────────────────────────────────────────────────────────────────┘

Step 1: User Request
├─ User runs: curl -X POST https://DOMAIN/api/RequestAccess \
│             -d '{"ip": "YOUR_IP_ADDRESS"}'
└─ Function triggered via HTTP

Step 2: Authentication & Validation
├─ Verify Azure service principal identity
├─ Validate IP format (ipv4)
├─ Check authorization level
└─ Set 1-hour expiration window

Step 3: Create Firewall Rule
├─ Generate unique rule name: JIT_{GUID}_{TIMESTAMP}
├─ Add rule to SQL Server firewall
├─ Rule allows access from User's IP only
└─ All other IPs still blocked

Step 4: Grant Database Access
├─ User's IP can now connect to SQL Server
├─ Connection uses TDE encryption
├─ Data is encrypted in transit (HTTPS/TLS)
└─ Activity logged to storage

Step 5: Automatic Cleanup
├─ Timer checks firewall rules every 5 minutes
├─ Identifies rules with expired TTL
├─ Removes expired rules automatically
└─ User access revoked

Step 6: Audit & Monitoring
├─ All requests logged to storage account
├─ Application Insights tracks metrics
├─ Alerts on suspicious activity
└─ Compliance dashboard updated
```

---

## Zero Trust Security Architecture

```
┌──────────────────────────────────────────────────────────┐
│            ZERO TRUST SECURITY PRINCIPLES                │
└──────────────────────────────────────────────────────────┘

Principle 1: Verify Identity
├─ Service Principal Authentication
├─ Azure AD Integration
└─ Managed Identity for Function

Principle 2: Least Privilege Access
├─ Private Endpoint (No Public Access)
├─ IP-Specific Firewall Rules
├─ 1-Hour Access Window
└─ Automatic Revocation

Principle 3: Protect Data
├─ Transparent Data Encryption (TDE)
├─ Encryption in Transit (HTTPS/TLS 1.2)
└─ GRS Storage for Audit Logs

Principle 4: Monitor & Detect
├─ Real-time Activity Logging
├─ Application Insights Telemetry
├─ Anomaly Detection
└─ Compliance Alerts

Principle 5: Assume Breach
├─ All Actions Audited
├─ Immutable Audit Trail
├─ User IP Recorded
└─ Automatic Revocation
```

---

## Network Architecture (Private Access)

```mermaid
graph TB
    INTERNET["🌐 Internet<br/>(External)"]
    
    subgraph AZURE["Azure Subscription"]
        subgraph VNET["Virtual Network<br/>(10.0.0.0/16)"]
            SUBNET["Private Subnet<br/>(10.0.0.0/24)"]
            FUNC["Azure Function<br/>(RequestAccess)"]
            APP["Your Applications"]
        end
        
        SQLPE["SQL Private Endpoint<br/>10.0.0.5"]
        SQLSRV["SQL Server<br/>(No Public IP)"]
        SQLDB["SQL Database<br/>(sentineldb)"]
        
        STORAGE["Storage Account<br/>(Private)"]
        
        DNS["Private DNS Zone<br/>database.windows.net"]
    end
    
    INTERNET -->|❌ DENIED| SQLSRV
    INTERNET -->|❌ DENIED| STORAGE
    
    FUNC -->|Private Link| SQLPE
    SQLPE -->|Secure Connection| SQLSRV
    SQLSRV -->|Manages| SQLDB
    
    APP -->|Query Data| SQLDB
    
    SQLSRV -->|Logs To| STORAGE
    FUNC -->|Logs To| STORAGE
    
    SUBNET -->|DNS Resolution| DNS
    DNS -->|Maps to| SQLPE
    
    style INTERNET fill:#FFB6B6
    style FUNC fill:#87CEEB
    style SQLPE fill:#90EE90
    style SQLSRV fill:#FFB347
    style SQLDB fill:#FFB6C1
    style STORAGE fill:#DDA0DD
    style DNS fill:#F0E68C
    style VNET fill:#E0FFFF
```

---

## Cost Breakdown

| Component | Cost/Month | Purpose |
|-----------|-----------|---------|
| Azure SQL Server | $15 | Database engine (serverless) |
| Azure SQL Database | ~$10 | Data storage (included) |
| Azure Function | $0-5 | JIT logic (consumption plan) |
| Storage Account | $5 | Audit logs (minimal storage) |
| Private Endpoint | $0.35 | SQL secure access |
| **Total Monthly** | **~$30-35** | Full JIT system |

---

## Key Components Summary

### 1. **Azure Function (RequestAccess)**
- **Language**: C# .NET 8 (Isolated)
- **Trigger**: HTTP POST
- **Purpose**: Accept JIT access requests and create firewall rules
- **Identity**: Managed Identity for SQL Server access
- **Cost**: Serverless (pay per invocation)

### 2. **Azure SQL Server**
- **Access**: Private endpoint only (no public access)
- **Encryption**: Transparent Data Encryption (TDE)
- **Firewall**: Dynamic rules managed by Function
- **Default State**: All access denied
- **Cost**: $15/month (serverless compute)

### 3. **Azure SQL Database**
- **Name**: sentineldb
- **Encryption**: TDE encrypted at rest
- **Storage**: GRS (Geo-Redundant)
- **Backup**: Automatic daily snapshots
- **Cost**: Included with SQL Server

### 4. **Storage Account**
- **Purpose**: Audit logs and compliance records
- **Access**: Private (no public access)
- **Containers**:
  - `jit-access-logs`: Request history
  - `audit-logs`: Activity records
- **Cost**: $5-10/month

### 5. **Application Insights**
- **Monitoring**: Function execution metrics
- **Alerts**: Suspicious activity detection
- **Dashboard**: Real-time visibility
- **Cost**: Included in Function cost

### 6. **Managed Identity**
- **Type**: System-Assigned (built-in)
- **Purpose**: Secure authentication to SQL Server
- **RBAC**: Fine-grained access control
- **Cost**: FREE

---

## How to Use This Diagram

### In GitHub
Mermaid diagrams render automatically in GitHub markdown files.

### In VS Code
1. Install: "Markdown Preview Mermaid Support"
2. Open preview: `Ctrl+Shift+V`
3. View rendered diagrams

### Online
Paste any mermaid code at: https://mermaid.live

---

## Deployment Order

```
1. Create Resource Group
2. Create Virtual Network & Subnet
3. Create Managed Identity
4. Create SQL Server (with Managed Identity)
5. Create SQL Database
6. Create Private Endpoint (SQL)
7. Create Private DNS Zone
8. Create Storage Account
9. Configure Auditing
10. Deploy Azure Function
11. Create Function Managed Identity
12. Grant Function permissions to SQL
13. Configure Application Insights
14. Deploy monitoring alerts
```

