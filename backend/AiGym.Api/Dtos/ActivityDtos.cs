using System.ComponentModel.DataAnnotations;

namespace AiGym.Api.Dtos;

public sealed record SaveActivitySessionRequest(
    Guid Id,
    [Required, RegularExpression("walking|running")] string ActivityType,
    DateTimeOffset StartedAt,
    [Range(1, 86400)] int DurationSeconds,
    [Range(0, 200000)] int? Steps,
    [Range(0, 1000000)] double? DistanceMeters,
    [MaxLength(5000)] IReadOnlyList<ActivityRoutePointRequest>? Route,
    bool DistanceEstimated,
    bool Completed);

public sealed record ActivityRoutePointRequest(
    [Range(-90, 90)] double Latitude,
    [Range(-180, 180)] double Longitude,
    DateTimeOffset RecordedAt,
    bool SegmentStart = false);

public sealed record ActivityRoutePointResponse(
    double Latitude,
    double Longitude,
    DateTimeOffset RecordedAt,
    bool SegmentStart);

public sealed record ActivitySessionResponse(
    Guid Id,
    string ActivityType,
    DateTimeOffset StartedAt,
    int DurationSeconds,
    int? Steps,
    double? DistanceMeters,
    IReadOnlyList<ActivityRoutePointResponse>? Route,
    bool DistanceEstimated,
    bool Completed);

public sealed record DailyActivityGoalRequest(
    [Range(0, 200000)] int StepsGoal,
    [Range(0, 1440)] int MinutesGoal,
    [Range(typeof(decimal), "0", "1000")] decimal DistanceGoalKm);

public sealed record DailyActivityGoalResponse(
    DateOnly Date,
    int StepsGoal,
    int MinutesGoal,
    decimal DistanceGoalKm,
    int Steps,
    int Minutes,
    double DistanceKm);
