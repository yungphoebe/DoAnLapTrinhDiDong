namespace AiGym.Api.Models;

public sealed class DailyActivityGoal
{
    public string UserId { get; set; } = string.Empty;
    public DateOnly Date { get; set; }
    public int StepsGoal { get; set; }
    public int MinutesGoal { get; set; }
    public decimal DistanceGoalKm { get; set; }
}
