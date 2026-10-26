using System.Security.Claims;
using AiGym.Api.Data;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ChallengesController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly IWebHostEnvironment _env;

    public ChallengesController(ApplicationDbContext db, IWebHostEnvironment env)
    {
        _db = db;
        _env = env;
    }

    private string GetUserId()
    {
        return User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("userId")
            ?? User.FindFirstValue(ClaimTypes.Name)
            ?? string.Empty;
    }

    private DateTime GetVietnamNow()
    {
        if (_env.IsDevelopment() && Request.Headers.TryGetValue("X-Simulate-Date", out var simDateStr))
        {
            if (DateTime.TryParse(simDateStr.ToString(), out var simDate))
            {
                return simDate;
            }
        }

        try
        {
            var tz = TimeZoneInfo.FindSystemTimeZoneById("SE Asia Standard Time");
            return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
        }
        catch
        {
            try
            {
                var tz = TimeZoneInfo.FindSystemTimeZoneById("Asia/Ho_Chi_Minh");
                return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
            }
            catch
            {
                return DateTime.UtcNow.AddHours(7);
            }
        }
    }

    private string GetTodayString() => GetVietnamNow().ToString("yyyy-MM-dd");

    private int GetSecondsUntilMidnight()
    {
        var vnNow = GetVietnamNow();
        var tomorrowMidnight = vnNow.Date.AddDays(1);
        var diff = (tomorrowMidnight - vnNow).TotalSeconds;
        return (int)Math.Max(0, diff);
    }

    [HttpGet]
    public async Task<IActionResult> GetChallenges()
    {
        var userId = GetUserId();
        var today = GetTodayString();
        var secondsUntilMidnight = GetSecondsUntilMidnight();
        var tomorrow = GetVietnamNow().Date.AddDays(1).ToString("yyyy-MM-dd");

        var userChallenges = await _db.UserChallenges
            .Where(x => x.UserId == userId)
            .ToListAsync();

        var result = ChallengeCatalog.Definitions.Select(def =>
        {
            var uc = userChallenges.FirstOrDefault(x => x.ChallengeId == def.Id);
            var isActive = uc != null;
            var isCompleted = uc?.IsCompleted ?? false;
            var stepIndex = uc?.CurrentStepIndex ?? 0;
            var currentProgress = uc?.CurrentProgress ?? 0;
            var lastProgressDate = uc?.LastProgressDate;
            var dailyLogs = uc?.GetDailyLogs() ?? new List<DailyProgressLog>();

            var todayLogs = dailyLogs.Where(l => l.date == today).ToList();
            var todayAmount = todayLogs.Sum(l => l.amount);

            var isLockedToday = uc != null && lastProgressDate == today;

            // Nếu hôm nay đã hoàn thành mục tiêu và bị khóa, hiển thị bước vừa hoàn thành (stepIndex - 1)
            var displayStepIndex = (isLockedToday && stepIndex > 0) ? stepIndex - 1 : stepIndex;
            var currentStep = displayStepIndex < def.Steps.Count ? def.Steps[displayStepIndex] : null;
            var todayTarget = currentStep?.TargetValue ?? 0;
            var unit = currentStep?.Unit ?? "";

            var totalTarget = def.Steps.Sum(s => s.TargetValue);
            var totalProgress = 0;
            for (int i = 0; i < def.Steps.Count; i++)
            {
                if (i < stepIndex) totalProgress += def.Steps[i].TargetValue;
                else if (i == stepIndex) totalProgress += Math.Min(currentProgress, def.Steps[i].TargetValue);
            }

            // Đã đạt/vượt mục tiêu hôm nay thì khóa lại cho đến 00:00 ngày mai
            var isTodayTargetReached = isLockedToday || (todayTarget > 0 && todayAmount >= todayTarget);
            var canUpdateToday = isActive && !isCompleted && !isLockedToday && !isTodayTargetReached;
            var isOverTarget = todayTarget > 0 && todayAmount > todayTarget;

            return new
            {
                id = def.Id,
                title = def.Title,
                description = def.Description,
                emoji = def.Emoji,
                difficulty = def.Difficulty,
                duration_days = def.DurationDays,
                medal_title = def.MedalTitle,
                medal_description = def.MedalDescription,
                is_active = isActive,
                is_completed = isCompleted,
                current_step_index = stepIndex,
                current_progress = currentProgress,
                today_target = todayTarget,
                unit = unit,
                total_target = totalTarget,
                total_progress = totalProgress,
                last_progress_date = lastProgressDate,
                can_update_today = canUpdateToday,
                today_amount = todayAmount,
                is_today_target_reached = isTodayTargetReached,
                is_over_target = isOverTarget,
                next_allowed_date = canUpdateToday ? today : tomorrow,
                seconds_until_next_day = secondsUntilMidnight,
                daily_logs = dailyLogs,
                start_date = uc?.StartDate,
                completed_at = uc?.CompletedAt
            };
        });

        return Ok(result);
    }

    [HttpPost("{id}/join")]
    public async Task<IActionResult> JoinChallenge(string id)
    {
        var userId = GetUserId();
        var def = ChallengeCatalog.Get(id);
        if (def == null)
        {
            return NotFound(new { message = "Thử thách không tồn tại." });
        }

        var existing = await _db.UserChallenges
            .FirstOrDefaultAsync(x => x.UserId == userId && x.ChallengeId == id);

        if (existing != null)
        {
            return Conflict(new { message = "Bạn đã tham gia thử thách này rồi." });
        }

        var uc = new UserChallenge
        {
            UserId = userId,
            ChallengeId = id,
            CurrentStepIndex = 0,
            CurrentProgress = 0,
            IsCompleted = false,
            StartDate = DateTime.UtcNow,
            LastProgressDate = null,
            DailyLogsJson = "[]"
        };

        _db.UserChallenges.Add(uc);
        await _db.SaveChangesAsync();

        return Ok(new { message = $"Đã tham gia thử thách \"{def.Title}\"!" });
    }

    [HttpPost("{id}/quit")]
    public async Task<IActionResult> QuitChallenge(string id)
    {
        var userId = GetUserId();
        var uc = await _db.UserChallenges
            .FirstOrDefaultAsync(x => x.UserId == userId && x.ChallengeId == id);

        if (uc == null)
        {
            return NotFound(new { message = "Bạn chưa tham gia thử thách này." });
        }

        if (uc.IsCompleted)
        {
            return BadRequest(new { message = "Thử thách này đã hoàn thành và lưu vào bộ sưu tập huy chương." });
        }

        _db.UserChallenges.Remove(uc);
        await _db.SaveChangesAsync();

        var def = ChallengeCatalog.Get(id);
        var title = def?.Title ?? id;
        return Ok(new { message = $"Đã từ bỏ thử thách \"{title}\"." });
    }

    public class ProgressRequest
    {
        public int Amount { get; set; }
    }

    [HttpPost("{id}/progress")]
    public async Task<IActionResult> UpdateProgress(string id, [FromBody] ProgressRequest request)
    {
        var userId = GetUserId();
        var def = ChallengeCatalog.Get(id);
        if (def == null)
        {
            return NotFound(new { message = "Thử thách không tồn tại." });
        }

        var uc = await _db.UserChallenges
            .FirstOrDefaultAsync(x => x.UserId == userId && x.ChallengeId == id);

        if (uc == null)
        {
            return NotFound(new { message = "Bạn chưa tham gia thử thách này." });
        }

        if (uc.IsCompleted)
        {
            return BadRequest(new { message = "Thử thách này đã hoàn thành. Không thể cập nhật thêm." });
        }

        var currentStep = uc.CurrentStepIndex < def.Steps.Count ? def.Steps[uc.CurrentStepIndex] : null;
        if (currentStep == null)
        {
            return BadRequest(new { message = "Không tìm thấy giai đoạn hiện tại của thử thách." });
        }

        // Validate amount: số nguyên > 0
        if (request.Amount <= 0)
        {
            return BadRequest(new { message = "Số lượng phải là số nguyên lớn hơn 0." });
        }

        var today = GetTodayString();
        var dailyLogs = uc.GetDailyLogs();
        var currentTodayAmount = dailyLogs.Where(l => l.date == today).Sum(l => l.amount);

        // Nếu hôm nay đã đạt hoặc vượt mục tiêu rồi -> KHÓA LẠI, trả 409
        if (uc.LastProgressDate == today)
        {
            var prevIndex = Math.Max(0, uc.CurrentStepIndex - 1);
            var prevStep = def.Steps[prevIndex];
            return StatusCode(409, new
            {
                message = $"Bạn đã hoàn thành mục tiêu hôm nay rồi ({currentTodayAmount}/{prevStep.TargetValue} {prevStep.Unit}). Hãy quay lại vào 00:00 ngày mai!"
            });
        }

        var todayTarget = currentStep.TargetValue;

        // Ghi nhận thêm hiệp tập này vào daily_logs
        dailyLogs.Add(new DailyProgressLog
        {
            date = today,
            amount = request.Amount,
            created_at = DateTime.UtcNow.ToString("o")
        });
        uc.SetDailyLogs(dailyLogs);

        var newTodayAmount = currentTodayAmount + request.Amount;
        bool isTargetReached = newTodayAmount >= todayTarget;
        bool isOverTarget = newTodayAmount > todayTarget;
        string message = "";

        if (isTargetReached)
        {
            // Đã đạt hoặc vượt mục tiêu -> Khóa lại cho ngày hôm nay
            uc.LastProgressDate = today;

            // Tiến trình của bước chỉ tính tối đa bằng targetValue (ví dụ 140/140 dù làm 145)
            uc.CurrentProgress = currentStep.TargetValue;
            uc.CurrentStepIndex++;

            if (uc.CurrentStepIndex >= def.Steps.Count)
            {
                uc.IsCompleted = true;
                uc.CompletedAt = DateTime.UtcNow;

                message = isOverTarget
                    ? $"🌟 BIỂU DƯƠNG XUẤT SẮC! Bạn đã làm {newTodayAmount}/{todayTarget} {currentStep.Unit} (vượt chỉ tiêu {newTodayAmount - todayTarget}) và HOÀN THÀNH TOÀN BỘ THỬ THÁCH \"{def.Title}\"! 🏅"
                    : $"Xuất sắc! Bạn đã hoàn thành {newTodayAmount}/{todayTarget} {currentStep.Unit} và hoàn thành thử thách \"{def.Title}\"! 🏅";
            }
            else
            {
                // Reset tiến độ bước tiếp theo
                uc.CurrentProgress = 0;

                message = isOverTarget
                    ? $"🌟 BIỂU DƯƠNG: Bạn đã làm {newTodayAmount}/{todayTarget} {currentStep.Unit} (Vượt chỉ tiêu {newTodayAmount - todayTarget} {currentStep.Unit})! Đã hoàn thành mục tiêu hôm nay và khóa cho ngày mai."
                    : $"Chúc mừng! Bạn đã hoàn thành đủ {newTodayAmount}/{todayTarget} {currentStep.Unit} hôm nay. Đã ghi nhận và khóa cho ngày mai.";
            }
        }
        else
        {
            // Chưa đủ mục tiêu ngày -> Tiếp tục cho phép nhập thêm các hiệp tiếp theo
            uc.CurrentProgress = newTodayAmount;
            var remaining = todayTarget - newTodayAmount;
            message = $"Đã ghi nhận thêm +{request.Amount} {currentStep.Unit}. Hôm nay đã làm: {newTodayAmount}/{todayTarget} {currentStep.Unit} (còn thiếu {remaining} {currentStep.Unit}).";
        }

        await _db.SaveChangesAsync();

        var tomorrow = GetVietnamNow().Date.AddDays(1).ToString("yyyy-MM-dd");
        var secondsUntilMidnight = GetSecondsUntilMidnight();

        return Ok(new
        {
            message = message,
            current_progress = uc.CurrentProgress,
            current_step_index = uc.CurrentStepIndex,
            is_completed = uc.IsCompleted,
            last_progress_date = uc.LastProgressDate,
            can_update_today = !isTargetReached && !uc.IsCompleted,
            today_amount = newTodayAmount,
            today_target = todayTarget,
            is_today_target_reached = isTargetReached,
            is_over_target = isOverTarget,
            next_allowed_date = isTargetReached ? tomorrow : today,
            seconds_until_next_day = secondsUntilMidnight
        });
    }
}
