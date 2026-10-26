using System.Text.Json;
using AiGym.Api.Dtos;

namespace AiGym.Api.Models;

public class DailyProgressLog
{
    public string date { get; set; } = string.Empty; // YYYY-MM-DD
    public int amount { get; set; }
    public string created_at { get; set; } = string.Empty; // ISO 8601
}

public class UserChallenge
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser? User { get; set; }
    public string ChallengeId { get; set; } = string.Empty;
    public int CurrentStepIndex { get; set; } = 0;
    public int CurrentProgress { get; set; } = 0;
    public bool IsCompleted { get; set; } = false;
    public DateTime StartDate { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }
    public string? LastProgressDate { get; set; } // YYYY-MM-DD
    public string DailyLogsJson { get; set; } = "[]";

    public List<DailyProgressLog> GetDailyLogs()
    {
        try
        {
            return JsonSerializer.Deserialize<List<DailyProgressLog>>(DailyLogsJson) ?? new List<DailyProgressLog>();
        }
        catch
        {
            return new List<DailyProgressLog>();
        }
    }

    public void SetDailyLogs(List<DailyProgressLog> logs)
    {
        DailyLogsJson = JsonSerializer.Serialize(logs);
    }

    // Reaching the step target locks the challenge until the next local day.
    public void AddProgress(ChallengeDefinition def, int amount, string date)
    {
        if (IsCompleted || amount <= 0 || LastProgressDate == date || CurrentStepIndex >= def.Steps.Count) return;
        var step = def.Steps[CurrentStepIndex];
        var logs = GetDailyLogs();
        logs.Add(new DailyProgressLog { date = date, amount = amount, created_at = DateTime.UtcNow.ToString("o") });
        SetDailyLogs(logs);
        var todayAmount = logs.Where(l => l.date == date).Sum(l => l.amount);
        if (todayAmount < step.TargetValue)
        {
            CurrentProgress = todayAmount;
            return;
        }
        LastProgressDate = date;
        CurrentStepIndex++;
        CurrentProgress = 0;
        if (CurrentStepIndex < def.Steps.Count) return;
        CurrentProgress = step.TargetValue;
        IsCompleted = true;
        CompletedAt = DateTime.UtcNow;
    }
}

public class ChallengeDefinition
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Emoji { get; set; } = string.Empty;
    public string Difficulty { get; set; } = "Medium";
    public int DurationDays { get; set; }
    // "session", "morningSession" or a camera exercise key such as "squat".
    public string Metric { get; set; } = "session";
    public string MedalTitle { get; set; } = string.Empty;
    public string MedalDescription { get; set; } = string.Empty;
    public List<ChallengeStepDefinition> Steps { get; set; } = new();
}

public class ChallengeStepDefinition
{
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int TargetValue { get; set; }
    public string Unit { get; set; } = string.Empty;
}

public static class ChallengeCatalog
{
    public static readonly List<ChallengeDefinition> Definitions = new()
    {
        new ChallengeDefinition
        {
            Id = "c1",
            Title = "7 Ngày Không Nghỉ",
            Description = "Tập gym liên tục 7 ngày không bỏ lỡ một buổi nào. Xây dựng thói quen kiên trì!",
            Emoji = "🔥",
            Difficulty = "Easy",
            DurationDays = 7,
            MedalTitle = "Huy Chương Kiên Trì",
            MedalDescription = "Hoàn thành 7 ngày tập không nghỉ",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Ngày 1-2", Description = "Tập ít nhất 2 buổi gym", TargetValue = 2, Unit = "buổi" },
                new ChallengeStepDefinition { Title = "Ngày 3-5", Description = "Tập thêm 3 buổi liên tiếp", TargetValue = 3, Unit = "buổi" },
                new ChallengeStepDefinition { Title = "Ngày 6-7", Description = "Hoàn thành 2 buổi cuối", TargetValue = 2, Unit = "buổi" }
            }
        },
        new ChallengeDefinition
        {
            Id = "c2",
            Title = "Vua Cardio 30 Ngày",
            Description = "Thực hiện tổng cộng 1000 cái jumping jack trong 30 ngày. Thử thách sức bền thực sự!",
            Emoji = "🏃",
            Difficulty = "Medium",
            DurationDays = 30,
            Metric = "jumpingJack",
            MedalTitle = "Huy Chương Cardio Vương",
            MedalDescription = "Hoàn thành 1000 jumping jack trong 30 ngày",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Tuần 1", Description = "200 jumping jack đầu tiên", TargetValue = 200, Unit = "cái" },
                new ChallengeStepDefinition { Title = "Tuần 2", Description = "Tiếp tục 300 cái", TargetValue = 300, Unit = "cái" },
                new ChallengeStepDefinition { Title = "Tuần 3", Description = "Đẩy lên 300 cái nữa", TargetValue = 300, Unit = "cái" },
                new ChallengeStepDefinition { Title = "Tuần 4", Description = "Về đích với 200 cái còn lại", TargetValue = 200, Unit = "cái" }
            }
        },
        new ChallengeDefinition
        {
            Id = "c3",
            Title = "Thách Thức Squat 1000",
            Description = "Thực hiện 1000 cái squat trong 10 ngày. Đùi thép cho bạn!",
            Emoji = "🦵",
            Difficulty = "Medium",
            DurationDays = 10,
            Metric = "squat",
            MedalTitle = "Huy Chương Đùi Thép",
            MedalDescription = "Hoàn thành 1000 squat trong 10 ngày",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Ngày 1-3", Description = "Warm-up: 300 squat", TargetValue = 300, Unit = "cái" },
                new ChallengeStepDefinition { Title = "Ngày 4-7", Description = "Tăng tốc: 400 squat", TargetValue = 400, Unit = "cái" },
                new ChallengeStepDefinition { Title = "Ngày 8-10", Description = "Về đích: 300 squat cuối", TargetValue = 300, Unit = "cái" }
            }
        },
        new ChallengeDefinition
        {
            Id = "c4",
            Title = "Chiến Binh Push-up",
            Description = "Từ 10 cái lên 100 cái push-up mỗi ngày trong 21 ngày. Vượt giới hạn bản thân!",
            Emoji = "💪",
            Difficulty = "Hard",
            DurationDays = 21,
            Metric = "pushup",
            MedalTitle = "Huy Chương Chiến Binh",
            MedalDescription = "Hoàn thành thử thách push-up 21 ngày",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Tuần 1", Description = "Bắt đầu: 10-30 cái/ngày", TargetValue = 140, Unit = "cái" },
                new ChallengeStepDefinition { Title = "Tuần 2", Description = "Tăng: 30-60 cái/ngày", TargetValue = 315, Unit = "cái" },
                new ChallengeStepDefinition { Title = "Tuần 3", Description = "Đỉnh cao: 60-100 cái/ngày", TargetValue = 560, Unit = "cái" }
            }
        },
        new ChallengeDefinition
        {
            Id = "c5",
            Title = "Thiền Gym Buổi Sáng",
            Description = "Tập gym vào buổi sáng trước 8h, 15 ngày liên tiếp. Sức mạnh bắt đầu từ bình minh!",
            Emoji = "🌅",
            Difficulty = "Easy",
            DurationDays = 15,
            Metric = "morningSession",
            MedalTitle = "Huy Chương Bình Minh",
            MedalDescription = "Hoàn thành 15 buổi tập sáng sớm",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Tuần 1", Description = "5 buổi tập buổi sáng", TargetValue = 5, Unit = "buổi" },
                new ChallengeStepDefinition { Title = "Tuần 2", Description = "5 buổi tiếp theo", TargetValue = 5, Unit = "buổi" },
                new ChallengeStepDefinition { Title = "Giai đoạn cuối", Description = "5 buổi về đích", TargetValue = 5, Unit = "buổi" }
            }
        },
        new ChallengeDefinition
        {
            Id = "c6",
            Title = "Thử Thách Vai Thép",
            Description = "Thực hiện 500 cái shoulder press trong 30 ngày. Vai thép - Tinh thần thép!",
            Emoji = "🏋️",
            Difficulty = "Hard",
            DurationDays = 30,
            Metric = "shoulderPress",
            MedalTitle = "Huy Chương Vai Thép",
            MedalDescription = "Hoàn thành 500 shoulder press trong 30 ngày",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Tuần 1", Description = "Khởi động: 100 cái", TargetValue = 100, Unit = "cái" },
                new ChallengeStepDefinition { Title = "Tuần 2", Description = "Tăng lên 150 cái", TargetValue = 150, Unit = "cái" },
                new ChallengeStepDefinition { Title = "Tuần 3-4", Description = "Chinh phục 250 cái cuối", TargetValue = 250, Unit = "cái" }
            }
        }
    };

    public static ChallengeDefinition? Get(string id) => Definitions.FirstOrDefault(d => d.Id == id);

    public static DateTime VietnamTime(DateTimeOffset value) =>
        TimeZoneInfo.ConvertTime(value, TimeZoneInfo.FindSystemTimeZoneById("Asia/Ho_Chi_Minh")).DateTime;

    // Only correct-form reps counted by the camera advance rep challenges.
    public static int CameraAmount(ChallengeDefinition def, IEnumerable<ExerciseSummary> exercises, DateTime localStart) => def.Metric switch
    {
        "session" => 1,
        "morningSession" => localStart.Hour < 8 ? 1 : 0,
        _ => exercises.Where(e => e.Exercise == def.Metric).Sum(e => e.CorrectReps)
    };
}
