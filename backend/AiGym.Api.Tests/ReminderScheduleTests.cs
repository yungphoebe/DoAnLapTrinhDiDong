using AiGym.Api.Models;
using AiGym.Api.Services;

namespace AiGym.Api.Tests;

public sealed class ReminderScheduleTests
{
    [Fact]
    public void BangkokSlots_RespectDaysBoundsAndDisabledKinds()
    {
        var s = new ReminderSettings { WorkoutEnabled = true, WaterEnabled = true, WeeklyEnabled = true };
        var from = new DateTime(2026, 10, 18, 0, 0, 0, DateTimeKind.Utc);
        var slots = ReminderSchedule.Occurrences(s, from, from.AddDays(1)).ToList();
        Assert.Equal(7, slots.Count(x => x.Kind == "water"));
        Assert.Contains(("workout", from.AddHours(11)), slots);
        Assert.Contains(("weekly", from.AddHours(13)), slots);
        s.WorkoutDays = "1,3,5"; s.WaterEnabled = false; s.WeeklyEnabled = false;
        Assert.Empty(ReminderSchedule.Occurrences(s, from, from.AddDays(1)));
        Assert.Equal(ReminderSchedule.EventId("a", "water", from), ReminderSchedule.EventId("a", "water", from));
        Assert.NotEqual(ReminderSchedule.EventId("a", "water", from), ReminderSchedule.EventId("b", "water", from));
    }
}
