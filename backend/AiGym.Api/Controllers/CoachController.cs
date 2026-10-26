using System.Security.Claims;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using AiGym.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

[ApiController]
[Route("api/coach")]
[Authorize]
public sealed class CoachController(ApplicationDbContext db, ILmStudioService ai) : ControllerBase
{
    private string? UserId => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");

    [HttpGet("conversations")]
    public async Task<ActionResult<IReadOnlyList<CoachConversationResponse>>> Conversations(CancellationToken ct)
    {
        if (UserId is null) return Unauthorized();
        var items = await db.CoachConversations.AsNoTracking().Where(x => x.UserId == UserId)
            .Include(x => x.Messages).OrderByDescending(x => x.UpdatedAt).Take(20).ToListAsync(ct);
        return Ok(items.Select(ToResponse).ToList());
    }

    [HttpPost("chat")]
    public async Task<ActionResult<CoachConversationResponse>> Chat(CoachMessageRequest request, CancellationToken ct)
    {
        if (UserId is null) return Unauthorized();
        var text = request.Message.Trim();
        if (text.Length == 0) return BadRequest(new { message = "Message is required." });
        var conversation = request.ConversationId.HasValue
            ? await db.CoachConversations.Include(x => x.Messages)
                .SingleOrDefaultAsync(x => x.Id == request.ConversationId && x.UserId == UserId, ct)
            : null;
        if (conversation is null)
        {
            conversation = new CoachConversation { UserId = UserId };
            db.CoachConversations.Add(conversation);
        }
        if (conversation.Messages.Count >= 100)
            return StatusCode(StatusCodes.Status429TooManyRequests, new { message = "Conversation limit reached." });
        var userMessage = new CoachMessage
        {
            ConversationId = conversation.Id,
            Sender = "user",
            Content = text,
            Status = "completed"
        };
        db.CoachMessages.Add(userMessage);
        try
        {
            var profile = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Id == UserId, ct);
            var recentContext = string.Join("\n", conversation.Messages
                .Where(x => x.Id != userMessage.Id && x.Status == "completed").OrderByDescending(x => x.CreatedAt)
                .Take(6).Reverse().Select(x => $"{x.Sender}: {x.Content}"));
            var context = $"Hồ sơ: mục tiêu={profile?.Goal ?? "chưa có"}, trình độ={profile?.TrainingLevel ?? "chưa có"}, " +
                          $"địa điểm={profile?.TrainingLocation ?? "chưa có"}. Lịch sử hội thoại gần đây:\n{recentContext}";
            var reply = await ai.ChatAsync(text, ct, context);
            var assistantMessage = new CoachMessage
            {
                ConversationId = conversation.Id,
                Sender = "assistant",
                Content = reply,
                Status = "completed"
            };
            db.CoachMessages.Add(assistantMessage);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            return StatusCode(StatusCodes.Status504GatewayTimeout, new
            {
                message = "LMStudio phản hồi quá chậm. Hãy thử câu hỏi ngắn hơn hoặc dùng model nhẹ hơn."
            });
        }
        catch (HttpRequestException)
        {
            var failedMessage = new CoachMessage
            {
                ConversationId = conversation.Id,
                Sender = "assistant",
                Content = "Coach tạm thời không khả dụng.",
                Status = "failed"
            };
            db.CoachMessages.Add(failedMessage);
            conversation.UpdatedAt = DateTimeOffset.UtcNow;
            await db.SaveChangesAsync(ct);
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                message = "Không thể kết nối LMStudio. Hãy mở LMStudio và nạp model AI phù hợp."
            });
        }
        catch (InvalidOperationException)
        {
            var failedMessage = new CoachMessage
            {
                ConversationId = conversation.Id,
                Sender = "assistant",
                Content = "LMStudio trả về dữ liệu không hợp lệ. Kiểm tra model và endpoint LMStudio.",
                Status = "failed"
            };
            db.CoachMessages.Add(failedMessage);
            conversation.UpdatedAt = DateTimeOffset.UtcNow;
            await db.SaveChangesAsync(ct);
            return StatusCode(StatusCodes.Status502BadGateway, new
            {
                message = "LMStudio trả về dữ liệu không hợp lệ. Kiểm tra model và endpoint LMStudio."
            });
        }
        conversation.UpdatedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);
        return Ok(ToResponse(conversation));
    }

    [HttpGet("insights")]
    public async Task<ActionResult<CoachInsightsResponse>> Insights(CancellationToken ct)
    {
        if (UserId is null) return Unauthorized();
        var since = DateTimeOffset.UtcNow.Date;
        var workouts = await db.WorkoutSessions.AsNoTracking()
            .Where(x => x.UserId == UserId && x.StartedAt >= since).ToListAsync(ct);
        var meals = await db.Meals.AsNoTracking()
            .Where(x => x.UserId == UserId && x.ConsumedAt >= since).ToListAsync(ct);
        var target = await db.DailyCalorieTargets.AsNoTracking()
            .Where(x => x.UserId == UserId && x.Date == DateOnly.FromDateTime(DateTime.UtcNow.Date))
            .Select(x => (decimal?)x.Calories).SingleOrDefaultAsync(ct);
        return Ok(new CoachInsightsResponse(
            workouts.Count, workouts.Sum(x => x.DurationSeconds) / 60,
            meals.Sum(x => x.Calories), target, workouts.Count > 0, meals.Count > 0,
            workouts.Count == 0 && meals.Count == 0 ? "Chưa đủ dữ liệu tập và ăn hôm nay." : "Dữ liệu lấy từ lịch sử hôm nay."));
    }

    [HttpPost("plan-proposal")]
    public async Task<ActionResult<CoachPlanProposalResponse>> PlanProposal(CancellationToken ct)
    {
        if (UserId is null) return Unauthorized();
        var profile = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Id == UserId, ct);
        var exercises = await db.Exercises.AsNoTracking().OrderBy(x => x.Id).Take(3).ToListAsync(ct);
        if (profile is null || exercises.Count == 0) return BadRequest(new { message = "Chưa đủ dữ liệu để tạo kế hoạch." });
        return Ok(new CoachPlanProposalResponse(
            $"Kế hoạch {profile.Goal ?? "cơ bản"}",
            profile.Goal ?? "Tăng cường sức khỏe", profile.TrainingLevel,
            exercises.Select((x, index) => new PlanExerciseRequest(x.Id, 3, 10, 60, index)).ToList()));
    }

    private static CoachConversationResponse ToResponse(CoachConversation value) =>
        new(value.Id, value.CreatedAt, value.UpdatedAt,
            value.Messages.OrderBy(x => x.CreatedAt)
                .Select(x => new CoachMessageResponse(x.Id, x.Sender, x.Content, x.Status, x.CreatedAt)).ToList());
}
