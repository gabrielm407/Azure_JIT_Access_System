using Azure;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Sql;
using Azure.ResourceManager.Sql.Models;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text.Json;

namespace JitAccessConfig
{
    public class JitAccess
    {
        private readonly ILogger _logger;

        public JitAccess(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<JitAccess>();
        }

        [Function("RequestAccess")]
        public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequestData req)
        {
            _logger.LogInformation("Processing JIT Access Request.");

            try 
            {
                // 1. Parse Request
                string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
                
                // Handle empty body case
                if (string.IsNullOrEmpty(requestBody)) 
                {
                     var badRequest = req.CreateResponse(HttpStatusCode.BadRequest);
                     await badRequest.WriteStringAsync("Request body cannot be empty.");
                     return badRequest;
                }

                var data = JsonSerializer.Deserialize<JsonElement>(requestBody);
                string clientIp = data.TryGetProperty("ip", out var ipVal) ? ipVal.ToString() : "127.0.0.1";

                // 2. Define Rule Name (JIT_UserHash_Ticks)
                var expiration = DateTime.UtcNow.AddHours(1);
                string ruleName = $"JIT_{Guid.NewGuid().ToString().Substring(0, 8)}_{expiration.Ticks}";

                // 3. Authenticate to Azure
                var armClient = new ArmClient(new DefaultAzureCredential());
                
                // 4. Get Environment Variables
                string subId = Environment.GetEnvironmentVariable("SUBSCRIPTION_ID");
                string rgName = Environment.GetEnvironmentVariable("RESOURCE_GROUP_NAME");
                string serverName = Environment.GetEnvironmentVariable("SQL_SERVER_NAME");

                var serverId = SqlServerResource.CreateResourceIdentifier(subId, rgName, serverName);
                SqlServerResource sqlServer = armClient.GetSqlServerResource(serverId);

                // 5. Create Firewall Rule
                var ruleData = new SqlFirewallRuleData()
                {
                    StartIPAddress = clientIp,
                    EndIPAddress = clientIp
                };

                await sqlServer.GetSqlFirewallRules().CreateOrUpdateAsync(WaitUntil.Completed, ruleName, ruleData);

                // 6. Return Success
                var response = req.CreateResponse(HttpStatusCode.OK);
                await response.WriteAsJsonAsync(new { 
                    status = "Access Granted", 
                    expires = expiration, 
                    rule = ruleName 
                });
                return response;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error granting access: {ex.Message}");
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errorResponse.WriteStringAsync($"Failed to apply security policy: {ex.Message}");
                return errorResponse;
            }
        }
    }
}