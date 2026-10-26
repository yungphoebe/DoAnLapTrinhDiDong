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
[Route("api/profile")]
public sealed class ProfileController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    public ProfileController(ApplicationDbContext context) => _context = context;

    private Task<ApplicationUser?> CurrentUser() => _context.Users.SingleOrDefaultAsync(
        user => user.Id == (User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId")));

    [HttpGet]
    public async Task<ActionResult<ProfileResponse>> Get()
    {
        var user = await CurrentUser();
        return user is null ? Unauthorized() : Ok(await Profile(user));
    }

    [HttpPut]
    public async Task<ActionResult<ProfileResponse>> Update(UpdateProfileRequest request)
    {
        var user = await CurrentUser();
        if (user is null) return Unauthorized();
        user.FullName = request.FullName.Trim();
        user.HeightCm = request.HeightCm;
        user.WeightKg = request.WeightKg;
        user.Age = request.Age;
        user.Gender = Clean(request.Gender);
        user.Goal = Clean(request.Goal);
        user.TrainingDays = request.TrainingDays;
        user.TrainingLocation = Clean(request.TrainingLocation);
        user.TrainingLevel = Clean(request.TrainingLevel);
        await _context.SaveChangesAsync();
        return Ok(await Profile(user));
    }

    [HttpPost("workouts")]
    public async Task<IActionResult> SaveWorkout(SaveWorkoutRequest request)
    {
        var user = await CurrentUser();
        if (user is null) return Unauthorized();
        if (request.Id == Guid.Empty || request.DurationSeconds is < 1 or > 86400 ||
            request.StartedAt < new DateTimeOffset(2000, 1, 1, 0, 0, 0, TimeSpan.Zero) ||
            request.StartedAt > DateTimeOffset.UtcNow ||
            request.StartedAt > DateTimeOffset.UtcNow.AddSeconds(5 - request.DurationSeconds))
            return BadRequest(new { message = "Invalid workout duration or start time." });

        var exercises = request.Exercises ?? [];
        var feedback = request.FeedbackCounts ?? [];
        if (exercises.Length > 3 || exercises.Any(item => item is null ||
                item.Exercise is not ("squat" or "pushup" or "jumpingJack") ||
                item.Reps is < 0 or > 100000 || item.CorrectReps is < 0 or > 100000 ||
                item.IncorrectReps is < 0 or > 100000 || item.Reps != item.CorrectReps + item.IncorrectReps) ||
            exercises.Select(item => item.Exercise).Distinct().Count() != exercises.Length ||
            feedback.Count > 20 || feedback.Any(item => string.IsNullOrWhiteSpace(item.Key) ||
                item.Key.Length > 80 || item.Value is < 0 or > 100000))
            return BadRequest(new { message = "Invalid exercise summary or feedback counts." });
        var exercisesJson = JsonSerializer.Serialize(exercises.OrderBy(item => item.Exercise, StringComparer.Ordinal));
        var feedbackJson = JsonSerializer.Serialize(new SortedDictionary<string, int>(feedback, StringComparer.Ordinal));
        var existing = await _context.WorkoutSessions.FindAsync(request.Id);
        if (existing is not null) return ExistingWorkout(existing, user.Id, request, exercisesJson, feedbackJson);
        _context.WorkoutSessions.Add(new WorkoutSession
        {
            Id = request.Id, UserId = user.Id,
            StartedAt = request.StartedAt.ToUniversalTime(), DurationSeconds = request.DurationSeconds,
            ExercisesJson = exercisesJson, FeedbackCountsJson = feedbackJson
        });
        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            // Concurrent retries can race the lookup; the primary key still permits one record.
            _context.ChangeTracker.Clear();
            existing = await _context.WorkoutSessions.FindAsync(request.Id);
            if (existing is null) throw;
            return ExistingWorkout(existing, user.Id, request, exercisesJson, feedbackJson);
        }
        return NoContent();
    }

    [HttpGet("workouts")]
    public async Task<ActionResult<IReadOnlyList<WorkoutResponse>>> History()
    {
        var user = await CurrentUser();
        if (user is null) return Unauthorized();
        var sessions = await _context.WorkoutSessions.AsNoTracking().Where(session => session.UserId == user.Id)
            .OrderByDescending(session => session.StartedAt).ThenByDescending(session => session.Id).Take(50).ToListAsync();
        return Ok(sessions.Select(session => new WorkoutResponse(session.Id, session.StartedAt, session.DurationSeconds,
            JsonSerializer.Deserialize<ExerciseSummary[]>(session.ExercisesJson)!,
            JsonSerializer.Deserialize<Dictionary<string, int>>(session.FeedbackCountsJson)!)).ToList());
    }

    private IActionResult ExistingWorkout(WorkoutSession existing, string userId, SaveWorkoutRequest request,
        string exercisesJson, string feedbackJson) =>
        existing.UserId == userId && existing.DurationSeconds == request.DurationSeconds && existing.StartedAt == request.StartedAt &&
        existing.ExercisesJson == exercisesJson && existing.FeedbackCountsJson == feedbackJson
            ? NoContent() : Conflict(new { message = "Workout ID already exists with different data." });

    private async Task<ProfileResponse> Profile(ApplicationUser user)
    {
        var sessions = await _context.WorkoutSessions.AsNoTracking().Where(session => session.UserId == user.Id)
            .Select(session => new { session.StartedAt, session.DurationSeconds }).ToListAsync();
        var offset = TimeSpan.FromHours(7);
        var today = DateTimeOffset.UtcNow.ToOffset(offset).Date;
        var days = sessions.Select(session => session.StartedAt.ToOffset(offset).Date).ToHashSet();
        var day = days.Contains(today) ? today : today.AddDays(-1);
        var streak = 0;
        while (days.Contains(day)) { streak++; day = day.AddDays(-1); }
        return new ProfileResponse(user.Id, user.Email ?? string.Empty, user.FullName,
            user.HeightCm, user.WeightKg, user.Age, user.Gender, user.Goal,
            user.TrainingDays, user.TrainingLocation, user.TrainingLevel,
            sessions.Count, sessions.Sum(session => (long)session.DurationSeconds),
            sessions.Where(session => session.StartedAt.ToOffset(offset).Date == today).Sum(session => (long)session.DurationSeconds), streak);
    }

    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
