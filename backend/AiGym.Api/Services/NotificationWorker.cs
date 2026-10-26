namespace AiGym.Api.Services;

public sealed class NotificationWorker(IServiceScopeFactory scopes, ILogger<NotificationWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(30));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopes.CreateScope();
                var now = DateTime.UtcNow;
                await scope.ServiceProvider.GetRequiredService<NotificationScheduler>().TickAsync(now);
                await scope.ServiceProvider.GetRequiredService<NotificationPush>().SendPendingAsync(
                    scope.ServiceProvider.GetRequiredService<Data.ApplicationDbContext>(), now, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogError(ex, "Notification scheduler failed; it will retry."); }
            try { if (!await timer.WaitForNextTickAsync(stoppingToken)) break; }
            catch (OperationCanceledException) { break; }
        }
    }
}
