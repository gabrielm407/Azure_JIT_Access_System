# Troubleshooting Runbook

This document details common errors encountered during the development of this system and their solutions.

## 🔴 Critical Error: "Sync Trigger Failed / Malformed Content"

### Symptoms
* **GitHub Action Error:** `Failed to perform sync trigger on function app. Function app may have malformed content.`
* **Azure Portal Status:** "Runtime Version: Error" or "Unreachable."

### Root Cause
This is caused by a **Region Mismatch** between the Function App and its Storage Account on a Linux Consumption Plan.
* *Scenario:* Function App was in `Canada Central`, but Storage Account defaulted to `East US`.
* *Impact:* The latency caused the file share mount to timeout during boot, leaving the app in a zombie state.

### Solution
1. Update Terraform to explicitly set `location = "Canada Central"` for the `azurerm_storage_account`.
2. **"Nuke and Pave":** You must destroy and recreate the resources to fix the corruption.
    ```bash
    terraform destroy -target=azurerm_linux_function_app.jit_function
    terraform apply
    ```

---

## 🔴 Error: "DenyPublicEndpointEnabled"

### Symptoms
* **API Response:** `400 Bad Request - Unable to create firewall rules when public network interface is disabled.`

### Root Cause
The Terraform configuration had `public_network_access_enabled = false` (Hardened Default). This physically disables the public listener, meaning **no** firewall rules can ever work.

### Solution
1. Update Terraform: Set `public_network_access_enabled = true`.
2. Security Note: This is safe because the default firewall rule list is empty (Deny All). The JIT app manages the allow-list dynamically.

---

## 🔴 Error: "Deployment Failed (Website Run From Package)"

### Symptoms
* Pipeline fails, App settings show `WEBSITE_RUN_FROM_PACKAGE = "1"`.

### Root Cause
Terraform was fighting GitHub Actions. Terraform tried to set the value to `"1"` (local zip), while GitHub tried to set it to a URL (remote zip).

### Solution
Remove the setting from Terraform entirely and add a lifecycle ignore block:
```hcl
lifecycle {
  ignore_changes = [
    app_settings["WEBSITE_RUN_FROM_PACKAGE"]
  ]
}