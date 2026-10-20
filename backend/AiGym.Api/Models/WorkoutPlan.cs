namespace AiGym.Api.Models;

public sealed class WorkoutPlan
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser? User { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Goal { get; set; }
    public string? Level { get; set; }
    public bool IsActive { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public ICollection<WorkoutPlanExercise> Exercises { get; } = [];
    public ICollection<PlanAppointment> Appointments { get; } = [];
}
