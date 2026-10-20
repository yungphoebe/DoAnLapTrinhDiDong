using System.Security.Claims;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

[Authorize]
[ApiController]
[Route("api")]
public sealed class WorkoutController(ApplicationDbContext db) : ControllerBase
{
    private string? UserId => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");

    [HttpGet("exercises")]
    public async Task<ActionResult<IReadOnlyList<ExerciseResponse>>> Exercises(CancellationToken ct)
        => Ok(await db.Exercises.AsNoTracking().OrderBy(x => x.Name)
            .Select(x => new ExerciseResponse(x.Id, x.Name, x.Description, x.MuscleGroup, x.Difficulty)).ToListAsync(ct));

    [HttpGet("workout-plans")]
    [HttpGet("plans")]
    public async Task<ActionResult<IReadOnlyList<WorkoutPlanResponse>>> Plans(CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        var plans = await db.WorkoutPlans.AsNoTracking().Where(x => x.UserId == userId)
            .Include(x => x.Exercises).ThenInclude(x => x.Exercise).OrderByDescending(x => x.CreatedAt).ToListAsync(ct);
        return Ok(plans.Select(ToResponse).ToList());
    }

    [HttpGet("workout-plans/{id:guid}")]
    [HttpGet("plans/{id:guid}")]
    public async Task<ActionResult<WorkoutPlanResponse>> Plan(Guid id, CancellationToken ct)
    {
        var plan = await OwnedPlan(id, ct);
        return plan is null ? NotFound() : Ok(ToResponse(plan));
    }

    [HttpPost("workout-plans")]
    [HttpPost("plans")]
    public async Task<ActionResult<WorkoutPlanResponse>> CreatePlan(CreateWorkoutPlanRequest request, CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        var exerciseIds = request.Exercises.Select(x => x.ExerciseId).Distinct().ToArray();
        var validIds = await db.Exercises.Where(x => exerciseIds.Contains(x.Id)).Select(x => x.Id).ToListAsync(ct);
        if (validIds.Count != exerciseIds.Length) return BadRequest("One or more exercises do not exist.");
        var plan = new WorkoutPlan { Id = Guid.NewGuid(), UserId = userId, Name = request.Name.Trim(),
            Goal = Clean(request.Goal), Level = Clean(request.Level), IsActive = request.IsActive, CreatedAt = DateTimeOffset.UtcNow };
        foreach (var item in request.Exercises)
            plan.Exercises.Add(new WorkoutPlanExercise { Id = Guid.NewGuid(), ExerciseId = item.ExerciseId,
                Sets = item.Sets, Reps = item.Reps, RestSeconds = item.RestSeconds, Order = item.Order });
        db.WorkoutPlans.Add(plan);
        await db.SaveChangesAsync(ct);
        await db.Entry(plan).Collection(x => x.Exercises).Query().Include(x => x.Exercise).LoadAsync(ct);
        return CreatedAtAction(nameof(Plan), new { id = plan.Id }, ToResponse(plan));
    }

    [HttpDelete("workout-plans/{id:guid}")]
    [HttpDelete("plans/{id:guid}")]
    public async Task<IActionResult> DeletePlan(Guid id, CancellationToken ct)
    {
        var plan = await OwnedPlan(id, ct);
        if (plan is null) return NotFound();
        db.WorkoutPlans.Remove(plan);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpGet("workout-plans/{planId:guid}/appointments")]
    public async Task<ActionResult<IReadOnlyList<AppointmentResponse>>> PlanAppointments(Guid planId, CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        var result = await db.PlanAppointments.AsNoTracking().Include(x => x.WorkoutPlan)
            .Where(x => x.UserId == userId && x.WorkoutPlanId == planId).OrderBy(x => x.StartsAt).ToListAsync(ct);
        return Ok(result.Select(ToResponse).ToList());
    }

    [HttpGet("appointments")]
    [HttpGet("schedules")]
    public async Task<ActionResult<IReadOnlyList<AppointmentResponse>>> Appointments(CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        var result = await db.PlanAppointments.AsNoTracking().Include(x => x.WorkoutPlan)
            .Where(x => x.UserId == userId).OrderBy(x => x.StartsAt).ToListAsync(ct);
        return Ok(result.Select(ToResponse).ToList());
    }

    [HttpPost("appointments")]
    [HttpPost("workout-plans/{ignoredPlanId:guid}/appointments")]
    public async Task<ActionResult<AppointmentResponse>> CreateAppointment(Guid? ignoredPlanId, CreateAppointmentRequest request, CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        var planId = request.WorkoutPlanId == Guid.Empty && ignoredPlanId.HasValue ? ignoredPlanId.Value : request.WorkoutPlanId;
        if (planId == Guid.Empty || request.StartsAt < new DateTimeOffset(2000, 1, 1, 0, 0, 0, TimeSpan.Zero) ||
            request.StartsAt > DateTimeOffset.UtcNow.AddYears(2))
            return BadRequest("Invalid plan or appointment time.");
        var plan = await db.WorkoutPlans.AsNoTracking().SingleOrDefaultAsync(x => x.Id == planId && x.UserId == userId, ct);
        if (plan is null) return NotFound();
        var appointmentId = request.Id.GetValueOrDefault(Guid.NewGuid());
        var existing = await db.PlanAppointments.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == appointmentId && x.UserId == userId, ct);
        if (existing is not null)
        {
            return existing.WorkoutPlanId == planId &&
                   existing.StartsAt == request.StartsAt.ToUniversalTime() &&
                   existing.DurationMinutes == request.DurationMinutes &&
                   existing.Notes == Clean(request.Notes)
                ? NoContent()
                : Conflict("Appointment ID already exists with different data.");
        }
        var appointment = new PlanAppointment { Id = appointmentId, UserId = userId,
            WorkoutPlanId = planId, StartsAt = request.StartsAt.ToUniversalTime(), DurationMinutes = request.DurationMinutes,
            Notes = Clean(request.Notes) };
        db.PlanAppointments.Add(appointment);
        await db.SaveChangesAsync(ct);
        appointment.WorkoutPlan = plan;
        return CreatedAtAction(nameof(Appointments), new { id = appointment.Id }, ToResponse(appointment));
    }

    [HttpPatch("appointments/{id:guid}/status")]
    public async Task<ActionResult<AppointmentResponse>> UpdateAppointment(Guid id, [FromBody] string status, CancellationToken ct)
    {
        var userId = UserId;
        var appointment = userId is null ? null : await db.PlanAppointments.Include(x => x.WorkoutPlan)
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);
        if (appointment is null) return NotFound();
        if (status is not ("scheduled" or "completed" or "cancelled")) return BadRequest("Invalid appointment status.");
        appointment.Status = status;
        await db.SaveChangesAsync(ct);
        return Ok(ToResponse(appointment));
    }

    [HttpGet("progress/weekly")]
    [HttpGet("reports/weekly")]
    [HttpGet("weekly-progress")]
    public async Task<ActionResult<WeeklyProgressResponse>> Weekly([FromQuery] DateTime? weekStart, CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        var localNow = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7));
        var start = (weekStart?.Date ?? localNow.Date);
        start = start.AddDays(-(int)start.DayOfWeek + (int)DayOfWeek.Monday);
        var localZone = TimeSpan.FromHours(7);
        var startUtc = new DateTimeOffset(start, localZone).ToUniversalTime();
        var endUtc = startUtc.AddDays(7);
        var planned = await db.PlanAppointments.AsNoTracking().Where(x => x.UserId == userId && x.StartsAt >= startUtc && x.StartsAt < endUtc).ToListAsync(ct);
        var completed = await db.WorkoutSessions.AsNoTracking().Where(x => x.UserId == userId && x.StartedAt >= startUtc && x.StartedAt < endUtc).ToListAsync(ct);
        var days = Enumerable.Range(0, 7).Select(i =>
        {
            var date = start.AddDays(i);
            return new DailyProgressResponse(date,
                planned.Count(x => x.StartsAt.ToOffset(localZone).Date == date),
                completed.Count(x => x.StartedAt.ToOffset(localZone).Date == date),
                completed.Where(x => x.StartedAt.ToOffset(localZone).Date == date).Sum(x => x.DurationSeconds));
        }).ToList();
        var percent = planned.Count == 0 ? 0 : (int)Math.Round(completed.Count * 100d / planned.Count);
        return Ok(new WeeklyProgressResponse(start, start.AddDays(6), planned.Count, completed.Count,
            completed.Sum(x => x.DurationSeconds), completed.Sum(x => x.DurationSeconds) / 60, percent, days));
    }

    private async Task<WorkoutPlan?> OwnedPlan(Guid id, CancellationToken ct)
        => UserId is null ? null : await db.WorkoutPlans.Include(x => x.Exercises).ThenInclude(x => x.Exercise)
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == UserId, ct);
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static WorkoutPlanResponse ToResponse(WorkoutPlan x) => new(x.Id, x.Name, x.Goal, x.Level, x.IsActive, x.CreatedAt,
        x.Exercises.OrderBy(e => e.Order).Select(e => new PlanExerciseResponse(e.Id, e.ExerciseId, e.Exercise?.Name ?? string.Empty,
            e.Sets, e.Reps, e.RestSeconds, e.Order)).ToList());
    private static AppointmentResponse ToResponse(PlanAppointment x) => new(x.Id, x.WorkoutPlanId, x.WorkoutPlan?.Name ?? string.Empty,
        x.StartsAt, x.DurationMinutes, x.Status, x.Notes);
}
