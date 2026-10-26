using AiGym.Api.Data;
using AiGym.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Services;

public sealed class NotificationScheduler(ApplicationDbContext db)
{
    public async Task TickAsync(DateTime utcNow, string? userId = null)
    {
        var query = db.ReminderSettings.AsNoTracking();
        if (userId is not null) query = query.Where(s => s.UserId == userId);
        var settings = await query.ToListAsync();
        foreach (var s in settings)
        {
            var from = new[] { s.LastProcessedUtc, s.UpdatedAt, utcNow.AddDays(-1) }.Max();
            foreach (var (kind, utc) in ReminderSchedule.Occurrences(s, from, utcNow))
            {
                var id = ReminderSchedule.EventId(s.UserId, kind, utc);
                var (title, body) = ReminderSchedule.Copy(kind);
                if (db.Database.IsSqlServer())
                {
                    await db.Database.ExecuteSqlInterpolatedAsync($"""
                        INSERT INTO dbo.UserNotifications
                        (Id, UserId, Kind, Title, Body, ScheduledAtUtc, CreatedAt, SettingsRevision, PushSent, PushAttempts)
                        SELECT {id}, {s.UserId}, {kind}, {title}, {body}, {utc}, {utcNow}, {s.Revision}, {false}, {0}
                        WHERE NOT EXISTS (SELECT 1 FROM dbo.UserNotifications WITH (UPDLOCK, HOLDLOCK) WHERE Id = {id})
                        """);
                }
                else if (!await db.UserNotifications.AnyAsync(n => n.Id == id))
                {
                    db.UserNotifications.Add(new UserNotification { Id = id, UserId = s.UserId, Kind = kind,
                        Title = title, Body = body, ScheduledAtUtc = utc, CreatedAt = utcNow, SettingsRevision = s.Revision });
                    await db.SaveChangesAsync();
                }
            }
            if (db.Database.IsRelational())
                await db.ReminderSettings.Where(x => x.UserId == s.UserId && x.Revision == s.Revision && x.LastProcessedUtc < utcNow)
                    .ExecuteUpdateAsync(set => set.SetProperty(x => x.LastProcessedUtc, utcNow));
            else
            {
                var tracked = await db.ReminderSettings.FindAsync(s.UserId);
                if (tracked is not null && tracked.Revision == s.Revision) { tracked.LastProcessedUtc = utcNow; await db.SaveChangesAsync(); }
            }
        }
    }
}
