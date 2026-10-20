using AiGym.Api.Models;

namespace AiGym.Api.Dtos;

public sealed class ReminderSettingsDto
{
    public bool WorkoutEnabled { get; set; }
    public string WorkoutTime { get; set; } = "18:00";
    public int[] WorkoutDays { get; set; } = [1, 2, 3, 4, 5, 6, 7];
    public bool WaterEnabled { get; set; }
    public string WaterStart { get; set; } = "09:00";
    public string WaterEnd { get; set; } = "21:00";
    public int WaterIntervalMinutes { get; set; } = 120;
    public bool WeeklyEnabled { get; set; }
    public int WeeklyDay { get; set; } = 7;
    public string WeeklyTime { get; set; } = "20:00";
    public string TimeZone { get; set; } = "Asia/Bangkok";
    public long Revision { get; set; }

    public static bool Minute(string? value, out int minute)
    {
        minute = 0;
        if (!TimeOnly.TryParseExact(value, "HH:mm", out var time)) return false;
        minute = time.Hour * 60 + time.Minute;
        return true;
    }

    public bool Valid()
    {
        if (!Minute(WorkoutTime, out _) || !Minute(WaterStart, out var start) ||
            !Minute(WaterEnd, out var end) || !Minute(WeeklyTime, out _) || start > end ||
            WaterIntervalMinutes < 60 || WaterIntervalMinutes > 240 || WeeklyDay < 1 || WeeklyDay > 7 ||
            WorkoutDays is null || WorkoutDays.Length < 1 || WorkoutDays.Length > 7 || WorkoutDays.Any(d => d < 1 || d > 7) ||
            string.IsNullOrEmpty(TimeZone) || TimeZone.Length > 100) return false;
        try { TimeZoneInfo.FindSystemTimeZoneById(TimeZone); return true; }
        catch (TimeZoneNotFoundException) { return false; }
        catch (InvalidTimeZoneException) { return false; }
    }

    public void Apply(ReminderSettings settings)
    {
        Minute(WorkoutTime, out var workout); Minute(WaterStart, out var start);
        Minute(WaterEnd, out var end); Minute(WeeklyTime, out var weekly);
        settings.WorkoutEnabled = WorkoutEnabled; settings.WorkoutMinute = workout;
        settings.WorkoutDays = string.Join(',', WorkoutDays.Distinct().Order());
        settings.WaterEnabled = WaterEnabled; settings.WaterStartMinute = start; settings.WaterEndMinute = end;
        settings.WaterIntervalMinutes = WaterIntervalMinutes;
        settings.WeeklyEnabled = WeeklyEnabled; settings.WeeklyDay = WeeklyDay; settings.WeeklyMinute = weekly;
        settings.TimeZone = TimeZone;
    }

    public static ReminderSettingsDto From(ReminderSettings s) => new()
    {
        WorkoutEnabled = s.WorkoutEnabled, WorkoutTime = Format(s.WorkoutMinute),
        WorkoutDays = s.WorkoutDays.Split(',').Select(int.Parse).ToArray(),
        WaterEnabled = s.WaterEnabled, WaterStart = Format(s.WaterStartMinute), WaterEnd = Format(s.WaterEndMinute),
        WaterIntervalMinutes = s.WaterIntervalMinutes, WeeklyEnabled = s.WeeklyEnabled,
        WeeklyDay = s.WeeklyDay, WeeklyTime = Format(s.WeeklyMinute), TimeZone = s.TimeZone, Revision = s.Revision
    };
    private static string Format(int minute) => $"{minute / 60:00}:{minute % 60:00}";
}

public sealed record PushSubscriptionRequest(string Endpoint, string P256dh, string Auth, string SessionId);
public sealed record RemoveSubscriptionRequest(string Endpoint);
