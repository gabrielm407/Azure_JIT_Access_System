using Azure;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Sql;
using Azure.ResourceManager.Sql.Models;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using System.Text.RegularExpressions;

namespace JitAccessConfig
{
    public class Cleanup
    {
        private readonly ILogger _logger;

        public Cleanup(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<Cleanup>();
        }

        [Function("CleanupRules")]
        public async Task Run([TimerTrigger("0 */5 * * * *")] TimerInfo myTimer)
        {
            _logger.LogInformation($"Cleanup function started at: {DateTime.UtcNow}");

            try
            {
                // 1. Authenticate
                var armClient = new ArmClient(new DefaultAzureCredential());

                // 2. Get Configuration
                string subId = Environment.GetEnvironmentVariable("SUBSCRIPTION_ID");
                string rgName = Environment.GetEnvironmentVariable("RESOURCE_GROUP_NAME");
                string serverName = Environment.GetEnvironmentVariable("SQL_SERVER_NAME");

                if (string.IsNullOrEmpty(serverName))
                {
                    _logger.LogError("SQL_SERVER_NAME environment variable is missing.");
                    return;
                }

                // 3. Connect to SQL Server Resource
                var serverId = SqlServerResource.CreateResourceIdentifier(subId, rgName, serverName);
                SqlServerResource sqlServer = armClient.GetSqlServerResource(serverId);

                _logger.LogInformation($"Scanning SQL Server: {serverName} for expired rules...");

                // 4. Iterate through all Firewall Rules
                // Note: We use "GetAllAsync" to scroll through all rules
                await foreach (SqlFirewallRuleResource rule in sqlServer.GetSqlFirewallRules().GetAllAsync())
                {
                    string ruleName = rule.Data.Name;

                    // Only look at rules that match our JIT pattern: JIT_{Guid}_{Ticks}
                    if (ruleName.StartsWith("JIT_"))
                    {
                        string[] parts = ruleName.Split('_');
                        
                        // Safety check: Format must be JIT_Guid_Ticks (3 parts)
                        if (parts.Length == 3)
                        {
                            if (long.TryParse(parts[2], out long expirationTicks))
                            {
                                var expirationTime = new DateTime(expirationTicks, DateTimeKind.Utc);
                                
                                // 5. Check if Expired
                                if (DateTime.UtcNow > expirationTime)
                                {
                                    _logger.LogInformation($"Rule {ruleName} expired at {expirationTime}. Deleting now...");
                                    
                                    try 
                                    {
                                        await rule.DeleteAsync(WaitUntil.Completed);
                                        _logger.LogInformation($"Successfully deleted rule: {ruleName}");
                                    }
                                    catch (Exception delEx)
                                    {
                                        _logger.LogError($"Failed to delete rule {ruleName}: {delEx.Message}");
                                    }
                                }
                                else
                                {
                                    // Log this to prove we SAW the rule but decided not to delete it yet
                                    _logger.LogInformation($"Rule {ruleName} is active. Expires in {(expirationTime - DateTime.UtcNow).TotalMinutes:N0} minutes.");
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Critical error in Cleanup function: {ex.Message}");
            }
            
            _logger.LogInformation("Cleanup scan completed.");
        }
    }
}