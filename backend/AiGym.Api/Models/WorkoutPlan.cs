namespace AiGym.Api.Models;

public sealed class WorkoutPlan
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser? User { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Goal { get; set; }
    public string? Level { get; set; }
    public int DaysPerWeek { get; set; }
    public int SessionMinutes { get; set; }
    public string? TrainingLocation { get; set; }
    public string? Equipment { get; set; }
    public bool IsActive { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public ICollection<WorkoutPlanExercise> Exercises { get; } = [];
    public ICollection<WorkoutPlanExerciseResult> ExerciseResults { get; } = [];
    public ICollection<PlanAppointment> Appointments { get; } = [];
}
