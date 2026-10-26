using System.ComponentModel.DataAnnotations;

namespace AiGym.Api.Dtos;

/// <summary>Exercise catalog item.</summary>
public sealed record ExerciseResponse(int Id, string Name, string? Description, string? MuscleGroup, string? Difficulty);

/// <summary>Exercise included in a workout plan.</summary>
public sealed record PlanExerciseRequest([Range(1, int.MaxValue)] int ExerciseId, [Range(1, 100)] int Sets,
    [Range(1, 1000)] int Reps, [Range(0, 3600)] int RestSeconds, [Range(0, 1000)] int Order);

/// <summary>Payload for creating a workout plan.</summary>
public sealed record CreateWorkoutPlanRequest
{
    [Required, StringLength(120)] public required string Name { get; init; }
    [StringLength(120)] public string? Goal { get; init; }
    [StringLength(60)] public string? Level { get; init; }
    public bool IsActive { get; init; }
    public PlanExerciseRequest[] Exercises { get; init; } = [];
}

/// <summary>Workout plan returned by the API.</summary>
public sealed record WorkoutPlanResponse(Guid Id, string Name, string? Goal, string? Level, bool IsActive,
    DateTimeOffset CreatedAt, IReadOnlyList<PlanExerciseResponse> Exercises);

/// <summary>Exercise assignment returned in a plan.</summary>
public sealed record PlanExerciseResponse(Guid Id, int ExerciseId, string ExerciseName, int Sets, int Reps,
    int RestSeconds, int Order);

/// <summary>Payload for scheduling a workout plan.</summary>
public sealed record CreateAppointmentRequest
{
    public Guid? Id { get; init; }
    [Required] public required Guid WorkoutPlanId { get; init; }
    public DateTimeOffset StartsAt { get; init; }
    [Range(1, 1440)] public int DurationMinutes { get; init; } = 60;
    [StringLength(500)] public string? Notes { get; init; }
}

/// <summary>Scheduled workout appointment.</summary>
public sealed record AppointmentResponse(Guid Id, Guid WorkoutPlanId, string PlanName, DateTimeOffset StartsAt,
    int DurationMinutes, string Status, string? Notes);

/// <summary>Weekly workout progress report.</summary>
public sealed record WeeklyProgressResponse(DateTime StartDate, DateTime EndDate, int PlannedWorkouts,
    int CompletedWorkouts, int TotalWorkoutSeconds, int CompletedMinutes, int CompletionPercent,
    IReadOnlyList<DailyProgressResponse> Days);

/// <summary>Progress for one day in a weekly report.</summary>
public sealed record DailyProgressResponse(DateTime Date, int PlannedWorkouts, int CompletedWorkouts, int WorkoutSeconds);
