# Architecture Design: JIT Access Flow

## High-Level Design
The system follows a **Zero Trust** model. The database has no permanent public access. Access is granted only upon request, for a specific identity, from a specific location, for a limited time.

### Architecture Diagram
```mermaid
sequenceDiagram
    participant Dev as Developer (User)
    participant Func as Azure Function (JIT Access)
    participant MI as Managed Identity
    participant ARM as Azure Resource Manager
    participant SQL as Azure SQL Server
    participant Logs as App Insights

    Note over SQL: Default State: Firewall Deny All

    Dev->>Func: POST /api/RequestAccess {IP: 1.2.3.4}
    Func->>Logs: Log "Access Requested"
    Func->>MI: Authenticate as "SQL Security Manager"
    MI-->>Func: Return Access Token
    
    Func->>ARM: Create Firewall Rule "JIT_User_Timestamp"
    ARM->>SQL: Update Network Security
    SQL-->>ARM: Success
    
    Func-->>Dev: 200 OK "Access Granted for 1 Hour"
    
    Note over Func: ... 5 Minutes Later ...
    
    Func->>Func: Cleanup Timer Trigger
    Func->>ARM: Check for Expired Rules
    ARM->>SQL: Delete Rule "JIT_User_Timestamp"
    Func->>Logs: Log "Access Revoked"