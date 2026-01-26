using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Sql;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

public class Cleanup
{
    private readonly ILogger _logger;

    public Cleanup(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<Cleanup>();
    }

    [Function("CleanupRules")]
    public async Task Run([TimerTrigger("0 */5 * * * *")] TimerInfo myTimer) // Runs every 5 mins
    {
        _logger.LogInformation($"Cleanup Audit running at: {DateTime.Now}");

        var armClient = new ArmClient(new DefaultAzureCredential());
        string subId = Environment.GetEnvironmentVariable("SUBSCRIPTION_ID");
        string rgName = Environment.GetEnvironmentVariable("RESOURCE_GROUP_NAME");
        string serverName = Environment.GetEnvironmentVariable("SQL_SERVER_NAME");

        var serverId = SqlServerResource.CreateResourceIdentifier(subId, rgName, serverName);
        SqlServerResource sqlServer = armClient.GetSqlServerResource(serverId);

        // Iterate all rules
        await foreach (SqlFirewallRuleResource rule in sqlServer.GetSqlFirewallRules())
        {
            if (rule.Data.Name.StartsWith("JIT_"))
            {
                var parts = rule.Data.Name.Split('_');
                // Name format: JIT_{guid}_{ticks}
                if (parts.Length == 3 && long.TryParse(parts[2], out long tickExpire))
                {
                    if (DateTime.UtcNow.Ticks > tickExpire)
                    {
                        _logger.LogWarning($"Revoking expired access for rule: {rule.Data.Name}");
                        await rule.DeleteAsync(Azure.WaitUntil.Completed);
                    }
                }
            }
        }
    }
}