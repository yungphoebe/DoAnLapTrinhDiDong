using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Data;

public static class NotificationSchema
{
    public static Task EnsureAsync(ApplicationDbContext db) => !db.Database.IsSqlServer() ? Task.CompletedTask : db.Database.ExecuteSqlRawAsync("""
        IF OBJECT_ID(N'dbo.ReminderSettings', N'U') IS NULL
        CREATE TABLE dbo.ReminderSettings (
          UserId nvarchar(450) NOT NULL PRIMARY KEY REFERENCES dbo.AspNetUsers(Id) ON DELETE CASCADE,
          WorkoutEnabled bit NOT NULL, WorkoutMinute int NOT NULL, WorkoutDays nvarchar(20) NOT NULL,
          WaterEnabled bit NOT NULL, WaterStartMinute int NOT NULL, WaterEndMinute int NOT NULL, WaterIntervalMinutes int NOT NULL,
          WeeklyEnabled bit NOT NULL, WeeklyDay int NOT NULL, WeeklyMinute int NOT NULL, TimeZone nvarchar(100) NOT NULL,
          Revision bigint NOT NULL, UpdatedAt datetime2 NOT NULL, LastProcessedUtc datetime2 NOT NULL);
        IF OBJECT_ID(N'dbo.UserNotifications', N'U') IS NULL
        BEGIN
          CREATE TABLE dbo.UserNotifications (
            Id uniqueidentifier NOT NULL PRIMARY KEY, UserId nvarchar(450) NOT NULL REFERENCES dbo.AspNetUsers(Id) ON DELETE CASCADE,
            Kind nvarchar(20) NOT NULL, Title nvarchar(200) NOT NULL, Body nvarchar(500) NOT NULL,
            ScheduledAtUtc datetime2 NOT NULL, CreatedAt datetime2 NOT NULL, ReadAt datetime2 NULL,
            SettingsRevision bigint NOT NULL, PushSent bit NOT NULL, PushAttempts int NOT NULL,
            PushLeaseUntil datetime2 NULL, NextPushUtc datetime2 NULL);
          CREATE INDEX IX_UserNotifications_UserId_ScheduledAtUtc ON dbo.UserNotifications(UserId, ScheduledAtUtc);
        END
        IF OBJECT_ID(N'dbo.BrowserPushSubscriptions', N'U') IS NULL
        BEGIN
          CREATE TABLE dbo.BrowserPushSubscriptions (
            Id nvarchar(64) NOT NULL PRIMARY KEY, UserId nvarchar(450) NOT NULL REFERENCES dbo.AspNetUsers(Id) ON DELETE CASCADE,
            Endpoint nvarchar(2048) NOT NULL, P256dh nvarchar(100) NOT NULL, Auth nvarchar(32) NOT NULL,
            SessionId nvarchar(64) NOT NULL, UpdatedAt datetime2 NOT NULL);
          CREATE INDEX IX_BrowserPushSubscriptions_UserId ON dbo.BrowserPushSubscriptions(UserId);
        END
        """);
}
