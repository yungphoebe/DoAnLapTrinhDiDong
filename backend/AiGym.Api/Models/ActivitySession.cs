namespace AiGym.Api.Models;

public sealed class ActivitySession
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser? User { get; set; }
    public string ActivityType { get; set; } = "walking";
    public DateTimeOffset StartedAt { get; set; }
    public int DurationSeconds { get; set; }
    public int? Steps { get; set; }
    public double? DistanceMeters { get; set; }
    public string? RouteJson { get; set; }
    public bool DistanceEstimated { get; set; }
    public bool Completed { get; set; }
}
