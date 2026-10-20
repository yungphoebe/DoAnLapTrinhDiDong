using System.ComponentModel.DataAnnotations;

namespace AiGym.Api.Dtos;

/// <summary>Message sent to the authenticated Coach conversation.</summary>
public sealed record CoachMessageRequest
{
    [Required, StringLength(2000, MinimumLength = 1)]
    public required string Message { get; init; }
    public Guid? ConversationId { get; init; }
}

/// <summary>Message stored in a Coach conversation.</summary>
public sealed record CoachMessageResponse(
    Guid Id, string Sender, string Content, string Status, DateTimeOffset CreatedAt);

/// <summary>Coach conversation with its messages.</summary>
public sealed record CoachConversationResponse(
    Guid Id, DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt,
    IReadOnlyList<CoachMessageResponse> Messages);

/// <summary>Availability and source information for Coach progress insights.</summary>
public sealed record CoachInsightsResponse(
    int CompletedWorkouts, int WorkoutMinutes, decimal Calories, decimal? CalorieTarget,
    bool HasWorkoutData, bool HasNutritionData, string Message);

/// <summary>Workout plan proposal that requires user confirmation before saving.</summary>
public sealed record CoachPlanProposalResponse(
    string Name, string Goal, string? Level, IReadOnlyList<PlanExerciseRequest> Exercises);
