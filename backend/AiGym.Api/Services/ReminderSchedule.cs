using System.Security.Cryptography;
using System.Text;
using AiGym.Api.Models;

namespace AiGym.Api.Services;

public static class ReminderSchedule
{
    public static IEnumerable<(string Kind, DateTime Utc)> Occurrences(ReminderSettings settings, DateTime fromUtc, DateTime toUtc)
    {
        var zone = TimeZoneInfo.FindSystemTimeZoneById(settings.TimeZone);
        var first = TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(fromUtc, DateTimeKind.Utc), zone).Date;
        var last = TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(toUtc, DateTimeKind.Utc), zone).Date;
        var days = settings.WorkoutDays.Split(',').Select(int.Parse).ToHashSet();
        for (var date = first; date <= last; date = date.AddDays(1))
        {
            var day = date.DayOfWeek == DayOfWeek.Sunday ? 7 : (int)date.DayOfWeek;
            var slots = new List<(string Kind, int Minute)>();
            if (settings.WorkoutEnabled && days.Contains(day)) slots.Add(("workout", settings.WorkoutMinute));
            if (settings.WeeklyEnabled && day == settings.WeeklyDay) slots.Add(("weekly", settings.WeeklyMinute));
            if (settings.WaterEnabled && settings.WaterIntervalMinutes >= 60)
                for (var minute = settings.WaterStartMinute; minute <= settings.WaterEndMinute; minute += settings.WaterIntervalMinutes)
                    slots.Add(("water", minute));
            foreach (var (kind, minute) in slots)
            {
                var local = DateTime.SpecifyKind(date.AddMinutes(minute), DateTimeKind.Unspecified);
                if (zone.IsInvalidTime(local)) continue;
                var utc = TimeZoneInfo.ConvertTimeToUtc(local, zone);
                if (utc > fromUtc && utc <= toUtc) yield return (kind, utc);
            }
        }
    }

    public static Guid EventId(string userId, string kind, DateTime utc) => new(
        SHA256.HashData(Encoding.UTF8.GetBytes($"{userId.Length}:{userId}|{kind}|{utc.Ticks}"))[..16]);

    public static (string Title, string Body) Copy(string kind) => kind switch
    {
        "workout" => ("Đến giờ tập luyện", "Dành thời gian cho buổi tập hôm nay. Chạm để xem lịch tập."),
        "water" => ("Nhắc uống nước", "Đến giờ nghỉ một chút và uống nước. Chạm để xem lịch nhắc."),
        _ => ("Báo cáo tuần", "Nhìn lại tuần vừa qua. Chạm để mở báo cáo tuần.")
    };
}
