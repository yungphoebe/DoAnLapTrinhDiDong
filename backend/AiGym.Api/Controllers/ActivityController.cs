using System.Security.Claims;
using System.Text.Json;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/activity")]
public sealed class ActivityController(ApplicationDbContext db) : ControllerBase
{
    private string? UserId =>
        User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");

    [HttpGet("sessions")]
    public async Task<ActionResult<IReadOnlyList<ActivitySessionResponse>>> Sessions(
        [FromQuery] DateOnly? from, [FromQuery] DateOnly? to, CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        var query = db.ActivitySessions.AsNoTracking().Where(x => x.UserId == userId);
        if (from.HasValue)
            query = query.Where(x => x.StartedAt >= LocalDayStart(from.Value));
        if (to.HasValue)
            query = query.Where(x => x.StartedAt < LocalDayStart(to.Value.AddDays(1)));
        var sessions = await query.OrderByDescending(x => x.StartedAt).Take(100).ToListAsync(ct);
        return Ok(sessions.Select(ToResponse).ToList());
    }

    [HttpPost("sessions")]
    public async Task<ActionResult<ActivitySessionResponse>> SaveSession(
        SaveActivitySessionRequest request, CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        if (request.Id == Guid.Empty ||
            request.StartedAt < new DateTimeOffset(2000, 1, 1, 0, 0, 0, TimeSpan.Zero) ||
            request.StartedAt > DateTimeOffset.UtcNow.AddMinutes(1))
            return BadRequest("Invalid activity session.");

        var existing = await db.ActivitySessions.FindAsync([request.Id], ct);
        if (existing is not null)
        {
            if (existing.UserId != userId) return NotFound();
            if (SameSession(existing, userId, request))
                return NoContent();
            return Conflict(new { message = "Activity session ID already exists with different data." });
        }

        var session = new ActivitySession
        {
            Id = request.Id,
            UserId = userId,
            ActivityType = request.ActivityType,
            StartedAt = request.StartedAt.ToUniversalTime(),
            DurationSeconds = request.DurationSeconds,
            Steps = request.Steps,
            DistanceMeters = request.DistanceMeters,
            RouteJson = request.Route is null ? null : JsonSerializer.Serialize(request.Route),
            DistanceEstimated = request.DistanceEstimated,
            Completed = request.Completed
        };
        db.ActivitySessions.Add(session);
        await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(Sessions), ToResponse(session));
    }

    [HttpGet("goals/{date}")]
    public async Task<ActionResult<DailyActivityGoalResponse>> Goal(DateOnly date, CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        var goal = await db.DailyActivityGoals.AsNoTracking()
            .SingleOrDefaultAsync(x => x.UserId == userId && x.Date == date, ct);
        var (start, end) = (LocalDayStart(date), LocalDayStart(date.AddDays(1)));
        var sessions = await db.ActivitySessions.AsNoTracking()
            .Where(x => x.UserId == userId && x.StartedAt >= start && x.StartedAt < end)
            .ToListAsync(ct);
        return Ok(new DailyActivityGoalResponse(date, goal?.StepsGoal ?? 0, goal?.MinutesGoal ?? 0,
            goal?.DistanceGoalKm ?? 0, sessions.Sum(x => x.Steps ?? 0),
            sessions.Sum(x => x.DurationSeconds) / 60,
            sessions.Sum(x => x.DistanceMeters ?? 0) / 1000));
    }

    [HttpPut("goals/{date}")]
    public async Task<ActionResult<DailyActivityGoalResponse>> SaveGoal(
        DateOnly date, DailyActivityGoalRequest request, CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        if (request.StepsGoal == 0 && request.MinutesGoal == 0 && request.DistanceGoalKm == 0)
            return BadRequest("At least one daily activity target is required.");
        var goal = await db.DailyActivityGoals
            .SingleOrDefaultAsync(x => x.UserId == userId && x.Date == date, ct);
        if (goal is null)
        {
            goal = new DailyActivityGoal { UserId = userId, Date = date };
            db.DailyActivityGoals.Add(goal);
        }
        goal.StepsGoal = request.StepsGoal;
        goal.MinutesGoal = request.MinutesGoal;
        goal.DistanceGoalKm = request.DistanceGoalKm;
        await db.SaveChangesAsync(ct);
        return await Goal(date, ct);
    }

    private static DateTimeOffset LocalDayStart(DateOnly date) =>
        new DateTimeOffset(date.ToDateTime(TimeOnly.MinValue), TimeSpan.FromHours(7)).ToUniversalTime();

    private static bool SameSession(
        ActivitySession existing, string userId, SaveActivitySessionRequest request) =>
        existing.UserId == userId && existing.ActivityType == request.ActivityType &&
        existing.StartedAt == request.StartedAt.ToUniversalTime() &&
        existing.DurationSeconds == request.DurationSeconds && existing.Steps == request.Steps &&
        existing.DistanceMeters == request.DistanceMeters &&
        existing.RouteJson == (request.Route is null ? null : JsonSerializer.Serialize(request.Route)) &&
        existing.DistanceEstimated == request.DistanceEstimated && existing.Completed == request.Completed;

    private static ActivitySessionResponse ToResponse(ActivitySession x) =>
        new(x.Id, x.ActivityType, x.StartedAt, x.DurationSeconds, x.Steps,
            x.DistanceMeters,
            x.RouteJson is null
                ? null
                : JsonSerializer.Deserialize<List<ActivityRoutePointResponse>>(
                    x.RouteJson,
                    new JsonSerializerOptions(JsonSerializerDefaults.Web)),
            x.DistanceEstimated, x.Completed);
}
