using System.Security.Claims;
using System.Text.Json;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using AiGym.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

[Authorize]
[ApiController]
[Route("api")]
public sealed class WorkoutController(ApplicationDbContext db, ILmStudioService ai) : ControllerBase
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
            .Include(x => x.Exercises).ThenInclude(x => x.Exercise)
            .Include(x => x.Exercises).ThenInclude(x => x.Results)
            .OrderByDescending(x => x.CreatedAt).ToListAsync(ct);
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
        if (request.Exercises.Any(x => x.DayNumber > request.DaysPerWeek))
            return BadRequest("Exercise day cannot exceed the plan's weekly training days.");
        var exerciseIds = request.Exercises.Select(x => x.ExerciseId).Distinct().ToArray();
        var validIds = await db.Exercises.Where(x => exerciseIds.Contains(x.Id)).Select(x => x.Id).ToListAsync(ct);
        if (validIds.Count != exerciseIds.Length) return BadRequest("One or more exercises do not exist.");
        var plan = new WorkoutPlan { Id = Guid.NewGuid(), UserId = userId, Name = request.Name.Trim(),
            Goal = Clean(request.Goal), Level = Clean(request.Level), DaysPerWeek = request.DaysPerWeek,
            SessionMinutes = request.SessionMinutes, TrainingLocation = Clean(request.TrainingLocation),
            Equipment = Clean(request.Equipment), IsActive = request.IsActive, CreatedAt = DateTimeOffset.UtcNow };
        foreach (var item in request.Exercises)
            plan.Exercises.Add(new WorkoutPlanExercise { Id = Guid.NewGuid(), ExerciseId = item.ExerciseId,
                DayNumber = item.DayNumber, Sets = item.Sets, Reps = item.Reps, TargetSeconds = item.TargetSeconds,
                RestSeconds = item.RestSeconds, Order = item.Order });
        db.WorkoutPlans.Add(plan);
        await db.SaveChangesAsync(ct);
        await db.Entry(plan).Collection(x => x.Exercises).Query().Include(x => x.Exercise).LoadAsync(ct);
        return CreatedAtAction(nameof(Plan), new { id = plan.Id }, ToResponse(plan));
    }

    [HttpPut("workout-plans/{id:guid}")]
    public async Task<ActionResult<WorkoutPlanResponse>> UpdatePlan(
        Guid id, CreateWorkoutPlanRequest request, CancellationToken ct)
    {
        var plan = await OwnedPlan(id, ct);
        if (plan is null) return NotFound();
        if (request.Exercises.Any(x => x.DayNumber > request.DaysPerWeek))
            return BadRequest("Exercise day cannot exceed the plan's weekly training days.");
        var exerciseIds = request.Exercises.Select(x => x.ExerciseId).Distinct().ToArray();
        var validIds = await db.Exercises.Where(x => exerciseIds.Contains(x.Id)).Select(x => x.Id).ToListAsync(ct);
        if (validIds.Count != exerciseIds.Length) return BadRequest("One or more exercises do not exist.");

        var existingById = plan.Exercises.ToDictionary(x => x.Id);
        var requestedIds = request.Exercises.Where(x => x.Id.HasValue).Select(x => x.Id!.Value).ToArray();
        if (requestedIds.Distinct().Count() != requestedIds.Length ||
            requestedIds.Any(x => !existingById.ContainsKey(x)))
            return BadRequest("Exercise IDs must belong to this plan and may not repeat.");
        if (plan.Exercises.Any(x => x.Results.Count > 0 && !requestedIds.Contains(x.Id)))
            return Conflict("Completed exercise history must remain in the plan.");
        if (request.Exercises.Any(x => x.Id.HasValue &&
                existingById[x.Id.Value].Results.Count > 0 &&
                existingById[x.Id.Value].ExerciseId != x.ExerciseId))
            return Conflict("An exercise with saved results cannot be reassigned to another catalog item.");

        plan.Name = request.Name.Trim();
        plan.Goal = Clean(request.Goal);
        plan.Level = Clean(request.Level);
        plan.DaysPerWeek = request.DaysPerWeek;
        plan.SessionMinutes = request.SessionMinutes;
        plan.TrainingLocation = Clean(request.TrainingLocation);
        plan.Equipment = Clean(request.Equipment);
        plan.IsActive = request.IsActive;

        var retainedIds = requestedIds.ToHashSet();
        foreach (var item in request.Exercises)
        {
            var target = item.Id.HasValue
                ? existingById[item.Id.Value]
                : new WorkoutPlanExercise { Id = Guid.NewGuid(), WorkoutPlanId = plan.Id };
            target.ExerciseId = item.ExerciseId;
            target.DayNumber = item.DayNumber;
            target.Sets = item.Sets;
            target.Reps = item.Reps;
            target.TargetSeconds = item.TargetSeconds;
            target.RestSeconds = item.RestSeconds;
            target.Order = item.Order;
            if (!item.Id.HasValue)
            {
                plan.Exercises.Add(target);
                retainedIds.Add(target.Id);
            }
        }
        foreach (var item in plan.Exercises.Where(x => !retainedIds.Contains(x.Id)).ToList())
        {
            if (item.Results.Count == 0) db.WorkoutPlanExercises.Remove(item);
        }
        await db.SaveChangesAsync(ct);
        return Ok(ToResponse(plan));
    }

    [HttpPost("workout-plans/{planId:guid}/exercises/{planExerciseId:guid}/results")]
    public async Task<ActionResult<WorkoutPlanExerciseResultResponse>> SavePlanExerciseResult(
        Guid planId, Guid planExerciseId, SavePlanExerciseResultRequest request, CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        if (request.Id == Guid.Empty || request.StartedAt < new DateTimeOffset(2000, 1, 1, 0, 0, 0, TimeSpan.Zero) ||
            request.StartedAt > DateTimeOffset.UtcNow.AddMinutes(1) ||
            request.ActualSets > 100 || request.ActualReps > 10000 ||
            (request.FeedbackCounts?.Count ?? 0) > 20 ||
            request.FeedbackCounts?.Any(x => string.IsNullOrWhiteSpace(x.Key) || x.Key.Length > 80 || x.Value is < 0 or > 100000) == true)
            return BadRequest("Invalid exercise result.");

        var planExercise = await db.WorkoutPlanExercises
            .Include(x => x.WorkoutPlan)
            .SingleOrDefaultAsync(x => x.Id == planExerciseId &&
                x.WorkoutPlanId == planId && x.WorkoutPlan!.UserId == userId, ct);
        if (planExercise is null) return NotFound();
        if (request.Completed && (request.ActualSets < planExercise.Sets ||
                (planExercise.TargetSeconds is null &&
                 request.ActualReps < planExercise.Sets * planExercise.Reps) ||
                (planExercise.TargetSeconds is not null &&
                 request.DurationSeconds < planExercise.TargetSeconds * planExercise.Sets)))
            return BadRequest("A completed exercise must meet its saved targets.");

        var feedback = JsonSerializer.Serialize(new SortedDictionary<string, int>(
            request.FeedbackCounts ?? [], StringComparer.Ordinal));
        var existing = await db.WorkoutPlanExerciseResults.FindAsync([request.Id], ct);
        if (existing is not null)
            return ExistingExerciseResult(existing, userId, planId, planExerciseId, request, feedback);
        var result = new WorkoutPlanExerciseResult
        {
            Id = request.Id,
            UserId = userId,
            WorkoutPlanId = planId,
            WorkoutPlanExerciseId = planExerciseId,
            StartedAt = request.StartedAt.ToUniversalTime(),
            DurationSeconds = request.DurationSeconds,
            ActualSets = request.ActualSets,
            ActualReps = request.ActualReps,
            Completed = request.Completed,
            FeedbackJson = feedback
        };
        db.WorkoutPlanExerciseResults.Add(result);
        await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(Plan), new { id = planId }, ToResponse(result));
    }

    [HttpPost("workout-plans/proposal")]
    public async Task<ActionResult<WorkoutPlanProposalResponse>> ProposePlan(
        WorkoutPlanProposalRequest request, CancellationToken ct)
    {
        if (UserId is null) return Unauthorized();
        var catalog = await db.Exercises.AsNoTracking().OrderBy(x => x.Id).ToListAsync(ct);
        if (catalog.Count == 0) return BadRequest("Exercise catalog is empty; cannot create a plan.");

        var catalogJson = JsonSerializer.Serialize(catalog.Select(x => new
        {
            exerciseId = x.Id,
            x.Name,
            x.MuscleGroup,
            x.Description
        }));
        var prompt = $$"""
            Tạo lịch tập tiếng Việt theo đầu vào.
            Mục tiêu: {{request.Goal}}
            Trình độ: {{request.Level}}
            Số buổi/tuần: {{request.DaysPerWeek}}
            Thời lượng mỗi buổi (phút): {{request.SessionMinutes}}
            Địa điểm: {{request.TrainingLocation}}
            Dụng cụ: {{request.Equipment ?? "Không có"}}
            Chỉ chọn exerciseId trong catalog bên dưới; không tự tạo bài mới.
            Trả lời duy nhất JSON đúng schema:
            {"name":"...","exercises":[{"exerciseId":1,"dayNumber":1,"sets":3,"reps":10,"targetSeconds":null,"restSeconds":60,"order":0}]}
            Mỗi ngày từ 1 đến {{request.DaysPerWeek}}, tối đa 8 bài mỗi ngày.
            Với bài đếm lần, đặt targetSeconds=null. Với bài theo thời lượng,
            đặt reps=1 và targetSeconds là số giây; không đặt đồng thời mục tiêu thời lượng và nhiều lần.
            Ưu tiên 2 bài mỗi ngày, tối đa 8 bài mỗi ngày.
            Catalog: {{catalogJson}}
            """;
        string reply;
        try
        {
            reply = await ai.ChatAsync(
                prompt,
                ct,
                "Tạo lịch tập có thể thực hiện bằng đúng danh mục bài tập.",
                maxOutputTokens: 1024);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            return StatusCode(StatusCodes.Status504GatewayTimeout, new { message = "AI tạo lịch quá thời gian chờ. Thử lại." });
        }
        catch (HttpRequestException)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new { message = "Không thể kết nối dịch vụ AI để tạo lịch." });
        }
        catch (InvalidOperationException)
        {
            return StatusCode(StatusCodes.Status502BadGateway, new
            {
                message = "AI trả về dữ liệu không hợp lệ. Kiểm tra model và endpoint LM Studio."
            });
        }

        try
        {
            var json = ExtractJson(reply);
            var parsed = JsonSerializer.Deserialize<AiPlanProposal>(json,
                new JsonSerializerOptions(JsonSerializerDefaults.Web));
            if (parsed is null || string.IsNullOrWhiteSpace(parsed.Name) ||
                parsed.Exercises is null || parsed.Exercises.Length == 0 ||
                parsed.Exercises.Length > request.DaysPerWeek * 8 ||
                parsed.Exercises.Select(x => x.DayNumber).Distinct().Count() != request.DaysPerWeek)
                return BadGateway("AI không tạo được lịch có cấu trúc hợp lệ. Hãy thử lại.");
            var byId = catalog.ToDictionary(x => x.Id);
            if (parsed.Exercises.Any(x => !byId.ContainsKey(x.ExerciseId) ||
                    x.DayNumber < 1 || x.DayNumber > request.DaysPerWeek ||
                    x.Sets is < 1 or > 100 || x.Reps is < 1 or > 1000 ||
                    x.TargetSeconds is < 1 or > 3600 ||
                    (x.TargetSeconds.HasValue && x.Reps != 1) ||
                    x.RestSeconds is < 0 or > 3600))
                return BadGateway("AI đề xuất bài tập hoặc mục tiêu không hợp lệ; lịch chưa được lưu.");
            var exercises = parsed.Exercises.Select(x =>
            {
                var exercise = byId[x.ExerciseId];
                return new PlanExerciseProposalResponse(x.ExerciseId, exercise.Name, exercise.MuscleGroup,
                    exercise.Description, x.DayNumber, x.Sets, x.Reps, x.TargetSeconds, x.RestSeconds, x.Order);
            }).OrderBy(x => x.DayNumber).ThenBy(x => x.Order).ToList();
            return Ok(new WorkoutPlanProposalResponse(
                parsed.Name.Trim(), request.Goal, request.Level, request.DaysPerWeek, request.SessionMinutes,
                request.TrainingLocation, Clean(request.Equipment), exercises));
        }
        catch (JsonException)
        {
            return BadGateway("AI trả về lịch không đúng định dạng. Lịch chưa được lưu.");
        }
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
        start = start.AddDays(-(((int)start.DayOfWeek + 6) % 7));
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
            .Include(x => x.Exercises).ThenInclude(x => x.Results)
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == UserId, ct);
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private ObjectResult BadGateway(string message) => StatusCode(StatusCodes.Status502BadGateway, new { message });
    private static string ExtractJson(string value)
    {
        var start = value.IndexOf('{');
        var end = value.LastIndexOf('}');
        if (start < 0 || end < start) throw new JsonException("AI response did not contain JSON.");
        return value[start..(end + 1)];
    }
    private sealed record AiPlanProposal(string Name, AiPlanExercise[]? Exercises);
    private sealed record AiPlanExercise(int ExerciseId, int DayNumber, int Sets, int Reps,
        int? TargetSeconds, int RestSeconds, int Order);
    private static WorkoutPlanResponse ToResponse(WorkoutPlan x) => new(x.Id, x.Name, x.Goal, x.Level, x.IsActive, x.CreatedAt,
        x.DaysPerWeek, x.SessionMinutes, x.TrainingLocation, x.Equipment,
        x.Exercises.OrderBy(e => e.Order).Select(e => new PlanExerciseResponse(e.Id, e.ExerciseId, e.Exercise?.Name ?? string.Empty,
            e.DayNumber, e.Sets, e.Reps, e.TargetSeconds, e.RestSeconds, e.Order, e.Exercise?.MuscleGroup, e.Exercise?.Description,
            e.Results.OrderByDescending(r => r.StartedAt).Select(ToResponse).ToList()))
            .OrderBy(e => e.DayNumber).ThenBy(e => e.Order).ToList());
    private ActionResult<WorkoutPlanExerciseResultResponse> ExistingExerciseResult(
        WorkoutPlanExerciseResult existing, string userId, Guid planId,
        Guid planExerciseId, SavePlanExerciseResultRequest request, string feedback)
    {
        if (existing.UserId == userId && existing.WorkoutPlanId == planId &&
            existing.WorkoutPlanExerciseId == planExerciseId &&
            existing.StartedAt == request.StartedAt.ToUniversalTime() &&
            existing.DurationSeconds == request.DurationSeconds && existing.ActualSets == request.ActualSets &&
            existing.ActualReps == request.ActualReps && existing.Completed == request.Completed &&
            existing.FeedbackJson == feedback)
            return NoContent();
        return Conflict(new { message = "Result ID already exists with different data." });
    }
    private static WorkoutPlanExerciseResultResponse ToResponse(WorkoutPlanExerciseResult result) =>
        new(result.Id, result.WorkoutPlanExerciseId, result.StartedAt, result.DurationSeconds, result.ActualSets,
            result.ActualReps, result.Completed,
            JsonSerializer.Deserialize<Dictionary<string, int>>(result.FeedbackJson ?? "{}") ?? []);
    private static AppointmentResponse ToResponse(PlanAppointment x) => new(x.Id, x.WorkoutPlanId, x.WorkoutPlan?.Name ?? string.Empty,
        x.StartsAt, x.DurationMinutes, x.Status, x.Notes);
}
