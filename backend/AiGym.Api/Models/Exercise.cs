namespace AiGym.Api.Models;

public sealed class Exercise
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? MuscleGroup { get; set; }
    public string? Difficulty { get; set; }
    public ICollection<WorkoutPlanExercise> PlanExercises { get; } = [];
}
