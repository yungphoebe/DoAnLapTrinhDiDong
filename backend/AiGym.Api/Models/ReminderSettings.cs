namespace AiGym.Api.Models;

public sealed class ReminderSettings
{
    public string UserId { get; set; } = "";
    public bool WorkoutEnabled { get; set; }
    public int WorkoutMinute { get; set; } = 1080;
    public string WorkoutDays { get; set; } = "1,2,3,4,5,6,7";
    public bool WaterEnabled { get; set; }
    public int WaterStartMinute { get; set; } = 540;
    public int WaterEndMinute { get; set; } = 1260;
    public int WaterIntervalMinutes { get; set; } = 120;
    public bool WeeklyEnabled { get; set; }
    public int WeeklyDay { get; set; } = 7;
    public int WeeklyMinute { get; set; } = 1200;
    public string TimeZone { get; set; } = "Asia/Bangkok";
    public long Revision { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastProcessedUtc { get; set; } = DateTime.UtcNow;
    public bool Enabled(string kind) => kind switch { "workout" => WorkoutEnabled, "water" => WaterEnabled, "weekly" => WeeklyEnabled, _ => false };
}
