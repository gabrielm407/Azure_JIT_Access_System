# Observability & Threat Hunting (KQL)

These Kusto Query Language (KQL) queries can be run in **Application Insights -> Logs** to monitor the JIT system.

## 1. Geo-Location Heatmap
**Purpose:** Detect if access requests are coming from high-risk countries or unexpected locations.

```kusto
requests
| where timestamp > ago(24h)
| where success == true
| summarize RequestCount = count() by client_CountryOrRegion, client_City
| order by RequestCount desc
| render barchart
```

## 2. Failed Access Spikes (Brute Force Detection)
**Purpose:** Alert the SOC if there is a sudden spike in failed requests (Potential Brute Force or DDoS).

```kusto
requests
| where timestamp > ago(24h)
| where success == false
| summarize Failures = count() by bin(timestamp, 15m)
| render timechart
```

## 3. Full Audit Trail
**Purpose:** Correlate specific "Access Granted" logs with the requesting IP address for compliance reporting.

```kusto
traces
| where message contains "JIT Access" or message contains "Revoking"
| project timestamp, message, operation_Id
| join kind=inner (
    requests
    | project timestamp, operation_Id, client_IP, client_CountryOrRegion
) on operation_Id
| project timestamp, message, client_IP, client_CountryOrRegion
| order by timestamp desc
```