using System.ComponentModel.DataAnnotations;

namespace AiGym.Api.Dtos;

public sealed record UpdateProfileRequest(
    [Required, StringLength(120)] string FullName,
    [Range(100, 230)] double? HeightCm,
    [Range(30, 250)] double? WeightKg,
    [Range(10, 100)] int? Age,
    [StringLength(30)] string? Gender,
    [StringLength(120)] string? Goal,
    [Range(1, 7)] int? TrainingDays,
    [StringLength(60)] string? TrainingLocation,
    [StringLength(60)] string? TrainingLevel);

public sealed record ExerciseSummary(string Exercise, int Reps, int CorrectReps, int IncorrectReps);

public sealed record SaveWorkoutRequest(Guid Id, int DurationSeconds, DateTimeOffset StartedAt,
    ExerciseSummary[]? Exercises = null, Dictionary<string, int>? FeedbackCounts = null);

public sealed record WorkoutResponse(Guid Id, DateTimeOffset StartedAt, int DurationSeconds,
    ExerciseSummary[] Exercises, Dictionary<string, int> FeedbackCounts);

public sealed record ProfileResponse(
    string UserId, string Email, string FullName,
    double? HeightCm, double? WeightKg, int? Age, string? Gender, string? Goal,
    int? TrainingDays, string? TrainingLocation, string? TrainingLevel,
    int WorkoutSessions, long TotalWorkoutSeconds, long TodayWorkoutSeconds, int StreakDays);
