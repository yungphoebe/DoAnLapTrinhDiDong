namespace AiGym.Api.Models;

public sealed class PlanAppointment
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser? User { get; set; }
    public Guid WorkoutPlanId { get; set; }
    public WorkoutPlan? WorkoutPlan { get; set; }
    public DateTimeOffset StartsAt { get; set; }
    public int DurationMinutes { get; set; }
    public string Status { get; set; } = "scheduled";
    public string? Notes { get; set; }
}
