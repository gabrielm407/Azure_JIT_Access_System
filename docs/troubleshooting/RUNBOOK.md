# 🔧 JIT Access Troubleshooting Runbook

This document catalogues the critical issues encountered during the implementation of the Zero Trust JIT Access system, along with their root causes and solutions.

---

## 1. Critical Error: "Sync Trigger Failed / Malformed Content"

### 🔴 Symptoms
* **GitHub Action Error:** `Failed to perform sync trigger on function app. Function app may have malformed content.`
* **Azure Portal Status:** "Runtime Version: Error" or "Unreachable."
* **Behavior:** The deployment pipeline fails during the `Azure/functions-action` step.

### 🔍 Root Cause (Two-Fold)
1.  **Configuration Conflict:** Terraform was enforcing `WEBSITE_RUN_FROM_PACKAGE = "1"` (expecting a local zip), while GitHub Actions was trying to set it to a remote SAS URL. This caused the app to look for a file that didn't exist.
2.  **Region Mismatch (Latency):** The Function App was deployed in `Canada Central`, but the Storage Account defaulted to `East US`. On Linux Consumption plans, the latency caused the file share mount to timeout during boot, corrupting the host.

### ✅ Solution
1.  **Align Regions:** Updated Terraform to explicitly set `location = "Canada Central"` for the `azurerm_storage_account`.
2.  **Ignore Deployment Settings:** Added a lifecycle block to `sql_server.tf` to stop Terraform from overwriting GitHub's deployment configuration:
    ```hcl
    lifecycle {
      ignore_changes = [
        app_settings["WEBSITE_RUN_FROM_PACKAGE"],
        app_settings["WEBSITE_CONTENTAZUREFILECONNECTIONSTRING"],
        app_settings["WEBSITE_CONTENTSHARE"]
      ]
    }
    ```
3.  **"Nuke and Pave":** Destroyed and recreated the corrupted resources to clear the "Zombie" state.
    ```bash
    terraform destroy -target=azurerm_linux_function_app.jit_function -target=azurerm_storage_account.func_storage
    terraform apply
    ```

---

## 2. Error: "DenyPublicEndpointEnabled" (400 Bad Request)

### 🔴 Symptoms
* **API Response:** `{"code":"DenyPublicEndpointEnabled", "message":"Unable to create or modify firewall rules when public network interface for the server is disabled."}`
* **Behavior:** The JIT Function runs but fails to create the firewall rule on the SQL Server.

### 🔍 Root Cause
The Terraform configuration followed strict security best practices by setting `public_network_access_enabled = false`. This physically disables the public listener. A JIT system *requires* the public listener to be active so it can dynamically allow specific IPs.

### ✅ Solution
1.  **Enable Public Access:** Updated `sql_server.tf`:
    ```hcl
    # trivy:ignore:AVD-AZU-0022 -- Required for JIT functionality
    public_network_access_enabled = true
    ```
2.  **Security Exception:** Added a comment to suppress the **Trivy** security scanner alert, documenting the business justification (JIT Access).
3.  **Defense in Depth:** Relied on the default "Deny All" firewall state to maintain security until the JIT system explicitly allows an IP.

---

## 3. Error: "401 Unauthorized" (With Bearer Header)

### 🔴 Symptoms
* **API Response:** `HTTP/1.1 401 Unauthorized` containing header `WWW-Authenticate: Bearer`.
* **Behavior:** `curl` commands using the Master Key (`x-functions-key`) fail.

### 🔍 Root Cause
**App Service Authentication ("Easy Auth")** was enabled on the Function App. This Azure platform feature intercepts requests *before* they reach the function code, demanding an Azure AD (Entra ID) token. Since `curl` was only providing a Function Key, the platform rejected it.

### ✅ Solution
1.  **Disable Easy Auth:** Navigate to **Settings -> Authentication** in the Azure Portal.
2.  **Remove Identity Provider:** Delete the configured provider and ensure "Allow Anonymous Access" is selected.
3.  **Retry:** The Function Key (`x-functions-key`) works immediately after, as authentication is handed off to the Function Host logic.

---

## 4. Error: "Failed to Fetch" (Azure Portal Test)

### 🔴 Symptoms
* **Portal Error:** Clicking "Test/Run" in the Azure Portal results in a red banner: `TypeError: Failed to fetch`.
* **Behavior:** You cannot trigger the function manually from the browser, but `curl` works fine.

### 🔍 Root Cause
**CORS (Cross-Origin Resource Sharing)**. The Azure Portal (`https://portal.azure.com`) is a web application trying to send requests to your Function App API. The Function App blocked this "Cross-Origin" request by default.

### ✅ Solution
Updated Terraform to explicitly allow the Azure Portal origin:

```hcl
site_config {
  cors {
    allowed_origins = ["[https://portal.azure.com](https://portal.azure.com)"]
    support_credentials = true
  }
}
```

---

## 5. Issue: Cleanup Timer Not Deleting Rules

### 🔴 Symptoms
* **Behavior:** The CleanupRules function runs (HTTP 202), but old firewall rules remain on the SQL Server.

### 🔍 Root Cause
1.  **Key Rotation:** After recreating the Function App, the Storage Account still held old encryption keys ("Secrets"), causing 401 errors internally.
2.  **Logic:** The function was running successfully but the expiration time logic required tuning to match the rule name format JIT_{Guid}_{Ticks}.

### ✅ Solution
1.  **Clear Secrets:** Deleted the azure-webjobs-secrets container in the Storage Account and restarted the app to regenerate fresh keys.
2.  **Observability:** Used KQL queries to verify the function was actually waking up on the logs of the Application Insights:

```hcl
traces | where operation_Name == "CleanupRules"
```