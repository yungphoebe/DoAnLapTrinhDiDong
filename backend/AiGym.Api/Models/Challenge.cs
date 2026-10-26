using System.Text.Json;

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
}

public class ChallengeDefinition
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Emoji { get; set; } = string.Empty;
    public string Difficulty { get; set; } = "Medium";
    public int DurationDays { get; set; }
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
            Title = "7 Ngay Khong Nghi",
            Description = "Tap gym lien tuc 7 ngay khong bo lo mot buoi nao. Xay dung thoi quen kien tri!",
            Emoji = "🔥",
            Difficulty = "Easy",
            DurationDays = 7,
            MedalTitle = "Huy Chuong Kien Tri",
            MedalDescription = "Hoan thanh 7 ngay tap khong nghi",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Ngay 1-2", Description = "Tap it nhat 2 buoi gym", TargetValue = 2, Unit = "buoi" },
                new ChallengeStepDefinition { Title = "Ngay 3-5", Description = "Tap them 3 buoi lien tiep", TargetValue = 3, Unit = "buoi" },
                new ChallengeStepDefinition { Title = "Ngay 6-7", Description = "Hoan thanh 2 buoi cuoi", TargetValue = 2, Unit = "buoi" }
            }
        },
        new ChallengeDefinition
        {
            Id = "c2",
            Title = "Vua Cardio 30 Ngay",
            Description = "Chay tong cong 100km trong 30 ngay. Thu thach suc ben thuc su!",
            Emoji = "🏃",
            Difficulty = "Medium",
            DurationDays = 30,
            MedalTitle = "Huy Chuong Cardio Vuong",
            MedalDescription = "Hoan thanh 100km chay bo trong 30 ngay",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Tuan 1", Description = "Chay 20km dau tien", TargetValue = 20, Unit = "km" },
                new ChallengeStepDefinition { Title = "Tuan 2", Description = "Tiep tuc 30km tiep theo", TargetValue = 30, Unit = "km" },
                new ChallengeStepDefinition { Title = "Tuan 3", Description = "Day len 30km nua", TargetValue = 30, Unit = "km" },
                new ChallengeStepDefinition { Title = "Tuan 4", Description = "Ve dich voi 20km con lai", TargetValue = 20, Unit = "km" }
            }
        },
        new ChallengeDefinition
        {
            Id = "c3",
            Title = "Thach Thuc Squat 1000",
            Description = "Thuc hien 1000 cai squat trong 10 ngay. Dui thep cho ban!",
            Emoji = "🦵",
            Difficulty = "Medium",
            DurationDays = 10,
            MedalTitle = "Huy Chuong Dui Thep",
            MedalDescription = "Hoan thanh 1000 squat trong 10 ngay",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Ngay 1-3", Description = "Warm-up: 300 squat", TargetValue = 300, Unit = "cai" },
                new ChallengeStepDefinition { Title = "Ngay 4-7", Description = "Tang toc: 400 squat", TargetValue = 400, Unit = "cai" },
                new ChallengeStepDefinition { Title = "Ngay 8-10", Description = "Ve dich: 300 squat cuoi", TargetValue = 300, Unit = "cai" }
            }
        },
        new ChallengeDefinition
        {
            Id = "c4",
            Title = "Chien Binh Push-up",
            Description = "Tu 10 cai len 100 cai push-up moi ngay trong 21 ngay. Vuot gioi han ban than!",
            Emoji = "💪",
            Difficulty = "Hard",
            DurationDays = 21,
            MedalTitle = "Huy Chuong Chien Binh",
            MedalDescription = "Hoan thanh thu thach push-up 21 ngay",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Tuan 1", Description = "Bat dau: 10-30 cai/ngay", TargetValue = 140, Unit = "cai" },
                new ChallengeStepDefinition { Title = "Tuan 2", Description = "Tang: 30-60 cai/ngay", TargetValue = 315, Unit = "cai" },
                new ChallengeStepDefinition { Title = "Tuan 3", Description = "Dinh cao: 60-100 cai/ngay", TargetValue = 560, Unit = "cai" }
            }
        },
        new ChallengeDefinition
        {
            Id = "c5",
            Title = "Thien Gym Buoi Sang",
            Description = "Tap gym vao buoi sang truoc 8h, 15 ngay lien tiep. Suc manh bat dau tu binh minh!",
            Emoji = "🌅",
            Difficulty = "Easy",
            DurationDays = 15,
            MedalTitle = "Huy Chuong Binh Minh",
            MedalDescription = "Hoan thanh 15 buoi tap sang som",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Tuan 1", Description = "5 buoi tap buoi sang", TargetValue = 5, Unit = "buoi" },
                new ChallengeStepDefinition { Title = "Tuan 2", Description = "5 buoi tiep theo", TargetValue = 5, Unit = "buoi" },
                new ChallengeStepDefinition { Title = "Giai doan cuoi", Description = "5 buoi ve dich", TargetValue = 5, Unit = "buoi" }
            }
        },
        new ChallengeDefinition
        {
            Id = "c6",
            Title = "Thu Thach Plank Thep",
            Description = "Plank tu 30 giay len 5 phut trong 30 ngay. Loi thep - Tinh than thep!",
            Emoji = "🧱",
            Difficulty = "Hard",
            DurationDays = 30,
            MedalTitle = "Huy Chuong Loi Thep",
            MedalDescription = "Hoan thanh thu thach plank 30 ngay",
            Steps = new()
            {
                new ChallengeStepDefinition { Title = "Tuan 1", Description = "Plank 30-60 giay/ngay", TargetValue = 7, Unit = "ngay" },
                new ChallengeStepDefinition { Title = "Tuan 2", Description = "Tang len 1-2 phut/ngay", TargetValue = 7, Unit = "ngay" },
                new ChallengeStepDefinition { Title = "Tuan 3-4", Description = "Chinh phuc 3-5 phut/ngay", TargetValue = 14, Unit = "ngay" }
            }
        }
    };

    public static ChallengeDefinition? Get(string id) => Definitions.FirstOrDefault(d => d.Id == id);
}
