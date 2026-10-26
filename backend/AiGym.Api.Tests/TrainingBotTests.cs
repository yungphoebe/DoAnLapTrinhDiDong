using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using AiGym.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Tests;

public sealed class TrainingBotTests
{
    [Fact]
    public async Task CatchUpAfterMidnightDoesNotCountYesterdaysWorkoutAsToday()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        await using var db = new ApplicationDbContext(options);
        var now = new DateTime(2026, 10, 25, 17, 5, 0, DateTimeKind.Utc);
        db.ReminderSettings.Add(new ReminderSettings { UserId = "a", WorkoutEnabled = true,
            UpdatedAt = now.AddHours(-7), LastProcessedUtc = now.AddHours(-7) });
        db.WorkoutSessions.Add(new WorkoutSession { Id = Guid.NewGuid(), UserId = "a",
            StartedAt = now.AddHours(-8), DurationSeconds = 600 });
        await db.SaveChangesAsync();
        await new NotificationScheduler(db).TickAsync(now, "a");
        Assert.DoesNotContain("đã tập", Assert.Single(await db.UserNotifications.ToListAsync()).Body);
    }

    [Fact]
    public void ToneDefaultsToEncouragementAndRoundTrips()
    {
        var settings = new ReminderSettings();
        Assert.False(ReminderSettingsDto.From(settings).BotRoastEnabled);
        new ReminderSettingsDto { BotRoastEnabled = true }.Apply(settings);
        Assert.True(ReminderSettingsDto.From(settings).BotRoastEnabled);
    }

    [Theory]
    [InlineData(false, false)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(true, true)]
    public async Task ScheduledBotUsesToneAndTodaysSavedWorkout(bool completed, bool roast)
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        await using var db = new ApplicationDbContext(options);
        // 18:00 in Vietnam; yesterday's workout must not count as today's.
        var now = new DateTime(2026, 10, 25, 11, 0, 0, DateTimeKind.Utc);
        db.ReminderSettings.Add(new ReminderSettings { UserId = "a", WorkoutEnabled = true,
            BotRoastEnabled = roast, UpdatedAt = now.AddMinutes(-1), LastProcessedUtc = now.AddMinutes(-1) });
        db.WorkoutSessions.Add(new WorkoutSession { Id = Guid.NewGuid(), UserId = "a",
            StartedAt = now.AddHours(completed ? -1 : -24), DurationSeconds = 30 });
        db.WorkoutSessions.Add(new WorkoutSession { Id = Guid.NewGuid(), UserId = "b",
            StartedAt = now.AddHours(-1), DurationSeconds = 600 });
        await db.SaveChangesAsync();
        await new NotificationScheduler(db).TickAsync(now, "a");
        var message = Assert.Single(await db.UserNotifications.ToListAsync());
        if (completed) Assert.Contains("đã tập", message.Body);
        else if (roast) Assert.Contains("chiếc ghế", message.Body);
        else Assert.DoesNotContain("chiếc ghế", message.Body);
        await new NotificationScheduler(db).TickAsync(now, "a");
        Assert.Single(await db.UserNotifications.ToListAsync());
    }
}
