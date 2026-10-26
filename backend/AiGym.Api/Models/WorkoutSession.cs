namespace AiGym.Api.Models;

public sealed class WorkoutSession
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser? User { get; set; }
    public DateTimeOffset StartedAt { get; set; }
    public int DurationSeconds { get; set; }
    public string ExercisesJson { get; set; } = "[]";
    public string FeedbackCountsJson { get; set; } = "{}";
}
