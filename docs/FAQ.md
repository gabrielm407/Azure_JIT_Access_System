# ❓ Frequently Asked Questions (FAQ)

This document answers common questions regarding the architecture, security posture, and operational logic of the JIT Access System.

---

## 🏗️ Architecture & Deployment

### Q: How does the Function App actually run the code?
**A:** We use the **Run From Package** deployment model (`WEBSITE_RUN_FROM_PACKAGE`).
1.  **Build:** GitHub Actions compiles the C# code and zips it into an artifact.
2.  **Upload:** This Zip file is uploaded to a specific container in the Storage Account.
3.  **Mount:** When the Function App starts, it does not "download" the files to a local drive. Instead, it **mounts the Zip file** directly from Blob Storage as a read-only virtual file system.
4.  **Execution:** The runtime reads the DLLs directly from this mount. This ensures atomicity—the code running is *exactly* what is in the artifact, with no chance of partial file locks or corruption.

### Q: Why did we have to move the Storage Account to the same region as the Function App?
**A:** On the **Linux Consumption Plan** (Serverless), the application files are mounted over the network. If the Function App is in `Canada Central` and the Storage is in `East US`, the network latency can cause the file share mount to time out during the "Cold Start" boot process. This leaves the app in a zombie state. Keeping them in the same region ensures the mount happens instantly.

---

## 🔐 Security & Access Control

### Q: Can anyone on the internet trigger the `RequestAccess` endpoint?
**A:** In the current MVP (Minimum Viable Product) configuration, **Yes.**
The HTTP Trigger is set to `AuthorizationLevel.Anonymous`, meaning the endpoint is public.
* **The Risk:** A malicious actor could technically add their IP to the firewall allow-list.
* **The Mitigation:** The firewall rules automatically expire after 1 hour. A hacker cannot "fill up" or permanently damage the configuration because the cleanup function is always running.

**Production Recommendation:**
For a production environment, we would enable **App Service Authentication (Easy Auth)** integrated with **Microsoft Entra ID (Azure AD)**. This would require the user to sign in with their corporate credentials before the Function App would accept the request.

### Q: What exactly does the Firewall Rule grant the user?
**A:** The Firewall Rule grants **Network Connectivity**, not Data Access.
* **Before the Rule:** The user's packets are dropped at the Azure edge. They cannot even reach the login prompt.
* **After the Rule:** The user can reach the SQL Server on TCP Port 1433.
* **Does this mean they can read data?** **NO.** They still need a valid Username/Password or an Entra ID Token to log in to the database.
    * *Analogy:* The Firewall is the "Bouncer" at the club door. The Database User is the "Ticket" you need to show inside. The JIT system just tells the bouncer to let you stand in line.

### Q: Why did we set `public_network_access_enabled = true` on the SQL Server?
**A:** This setting controls the "Master Switch" for the public firewall.
* If set to `false`, the public listener is physically disabled. No firewall rule—no matter who creates it—will ever work.
* By setting it to `true`, we turn the listener *on*, but the **default firewall rule list is empty**, which effectively acts as a "Deny All" policy. The JIT system manages the temporary exceptions to this policy.

---

## ⚙️ Operations & Troubleshooting

### Q: What happens if the `CleanupRules` function fails to run?
**A:** If the cleanup function fails (or the app crashes), the firewall rule will remain active beyond its 1-hour intended lifespan.
* **Detection:** We use Application Insights to monitor for failed invocations of the `CleanupRules` function.
* **Remediation:** The next time the function runs (every 5 minutes), it scans *all* rules. If it missed one previously, it will catch it on the next pass and delete it. This makes the system "Self-Healing."

### Q: Why do I sometimes see a 401 Unauthorized when testing locally or via Curl?
**A:** This usually indicates a mismatch in keys or authentication settings.
1.  **Keys:** The Function App requires a valid host key (`x-functions-key` header) or master key to run admin endpoints.
2.  **Easy Auth:** If "App Service Authentication" is enabled in the portal, the Azure platform intercepts the request before it reaches the code. For testing with keys, Easy Auth should be disabled (Anonymous).

### Q: How much does this solution cost?
**A:** It is extremely cost-effective:
* **Function App (Consumption):** 1 million executions per month are free. The JIT system likely uses <1,000. (**Free**)
* **Storage Account:** Only stores small logs and the zip file. (**<$0.05/month**)
* **SQL Server:** Standard rates apply, but the JIT system adds no extra cost to the SQL server itself.