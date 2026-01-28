# Azure JIT Access System (Zero Trust Architecture)

## Overview
This project implements a **Just-In-Time (JIT) Access System** for Azure SQL Database using a **Zero Trust** approach.

By default, the SQL Server firewall blocks **all** public access (`0.0.0.0/0` is blocked). When a developer needs access, they authenticate via an Azure Function, which validates their identity and temporarily opens the firewall for their specific IP address. The access rule is automatically revoked after a set duration (e.g., 1 hour).

### Key Features
* **Infrastructure as Code (IaC):** 100% Terraform-managed infrastructure.
* **Serverless Compute:** Azure Functions (.NET 8 Isolated) for request handling.
* **Shift-Left Security:** GitHub Actions pipeline with automated SAST (CodeQL) and IaC (Trivy) scanning.
* **Observability:** Application Insights integration with custom Kusto (KQL) threat detection queries.

## 📂 Documentation Structure

| Document | Description |
| :--- | :--- |
| 🏗️ **[Architecture Design](docs/architecture/jit-access-flow.md)** | System design, data flow diagrams, and security decisions. |
| 🚀 **[Deployment Guide](docs/deployment/pipeline-setup.md)** | How to set up the CI/CD pipeline and secrets. |
| 🔧 **[Troubleshooting Runbook](docs/troubleshooting/known-issues.md)** | Solutions for common deployment errors (e.g., Sync Trigger failed). |
| 📊 **[Observability & KQL](docs/observability/kql-queries.md)** | Custom dashboards and threat hunting queries. |

## 🛠️ Tech Stack
* **Cloud:** Microsoft Azure (Canada Central)
* **IaC:** Terraform
* **Language:** C# (.NET 8)
* **CI/CD:** GitHub Actions
* **Security Tools:** GitHub CodeQL, Trivy (Aqua Security)

---
*Project created for demonstration of Cloud Security & DevSecOps principles.*