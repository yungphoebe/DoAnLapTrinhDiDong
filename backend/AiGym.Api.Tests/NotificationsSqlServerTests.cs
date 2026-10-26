using AiGym.Api.Data;
using AiGym.Api.Models;
using AiGym.Api.Services;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Tests;
public sealed class NotificationsSqlServerTests
{
    [SqlServerFact]
    public async Task NotificationSchema_Upgrades_ConcurrentTicksDeduplicate_AndOffStopsFutureEvents()
    {
        var connection=new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("AIGYM_TEST_SQLSERVER")) {InitialCatalog=$"AiGymNotificationTest_{Guid.NewGuid():N}"};
        var options=new DbContextOptionsBuilder<ApplicationDbContext>().UseSqlServer(connection.ConnectionString).Options;
        await using var setup=new ApplicationDbContext(options);
        try{
            await setup.Database.EnsureCreatedAsync();
            await setup.Database.ExecuteSqlRawAsync("DROP TABLE dbo.UserNotifications; DROP TABLE dbo.BrowserPushSubscriptions; DROP TABLE dbo.ReminderSettings; DROP TABLE dbo.UserFeedback;");
            await NotificationSchema.EnsureAsync(setup);await NotificationSchema.EnsureAsync(setup);
            await SupportSchema.EnsureAsync(setup);await SupportSchema.EnsureAsync(setup);
            setup.Users.Add(new ApplicationUser{Id="a",FullName="A",UserName="a"});
            var now=new DateTime(2026,10,19,11,0,0,DateTimeKind.Utc);
            setup.ReminderSettings.Add(new ReminderSettings{UserId="a",WorkoutEnabled=true,Revision=1,UpdatedAt=now.AddMinutes(-1),LastProcessedUtc=now.AddMinutes(-1)});
            await setup.SaveChangesAsync();
            await Task.WhenAll(Enumerable.Range(0,8).Select(async _=>{
                await using var context=new ApplicationDbContext(options);await new NotificationScheduler(context).TickAsync(now);
            }));
            await using var reopened=new ApplicationDbContext(options);
            Assert.Equal(1,await reopened.UserNotifications.CountAsync());
            var row=await reopened.UserNotifications.SingleAsync();Assert.Equal("workout",row.Kind);
            Assert.Equal(DateTimeKind.Utc,row.ScheduledAtUtc.Kind);
            row.ReadAt=now;await reopened.SaveChangesAsync();
            await using(var readBack=new ApplicationDbContext(options))
                Assert.Equal(DateTimeKind.Utc,(await readBack.UserNotifications.SingleAsync()).ReadAt!.Value.Kind);
            var settings=await reopened.ReminderSettings.SingleAsync();settings.WorkoutEnabled=false;settings.Revision++;
            await reopened.SaveChangesAsync();await new NotificationScheduler(reopened).TickAsync(now.AddDays(1));
            Assert.Equal(1,await reopened.UserNotifications.CountAsync());
            reopened.UserFeedback.Add(new UserFeedback{Id=Guid.NewGuid(),UserId="a",Subject="Test",Content="Saved feedback"});await reopened.SaveChangesAsync();
            await using var final=new ApplicationDbContext(options);Assert.Equal("Saved feedback",(await final.UserFeedback.SingleAsync()).Content);
            Assert.Equal(DateTimeKind.Utc,(await final.UserFeedback.SingleAsync()).CreatedAt.Kind);
        }finally{await setup.Database.EnsureDeletedAsync();}
    }
}
