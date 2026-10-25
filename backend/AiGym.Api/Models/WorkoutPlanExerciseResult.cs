namespace AiGym.Api.Models;

public sealed class WorkoutPlanExerciseResult
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser? User { get; set; }
    public Guid WorkoutPlanId { get; set; }
    public WorkoutPlan? WorkoutPlan { get; set; }
    public Guid WorkoutPlanExerciseId { get; set; }
    public WorkoutPlanExercise? WorkoutPlanExercise { get; set; }
    public DateTimeOffset StartedAt { get; set; }
    public int DurationSeconds { get; set; }
    public int ActualSets { get; set; }
    public int ActualReps { get; set; }
    public bool Completed { get; set; }
    public string? FeedbackJson { get; set; }
}
