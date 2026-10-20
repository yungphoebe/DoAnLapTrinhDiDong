using System.ComponentModel.DataAnnotations;

namespace AiGym.Api.Dtos;

/// <summary>A food returned by nutrition search.</summary>
public sealed record FoodResponse(Guid Id, string Name, string? Brand, decimal CaloriesPer100g, decimal ProteinPer100g, decimal CarbsPer100g, decimal FatPer100g);
/// <summary>A food and amount in a meal.</summary>
public sealed record MealItemRequest(Guid FoodId, [param: Range(typeof(decimal), "0.01", "100000")] decimal Grams);
/// <summary>Payload for creating or replacing a meal.</summary>
public sealed record MealRequest([param: Required, StringLength(120)] string Name, DateTimeOffset ConsumedAt, [param: Required] MealItemRequest[] Items);
/// <summary>Meal with recalculated nutrition totals.</summary>
public sealed record MealResponse(Guid Id, string Name, DateTimeOffset ConsumedAt, decimal Calories, decimal Protein, decimal Carbs, decimal Fat, IReadOnlyList<MealItemResponse> Items);
/// <summary>A meal item with nutrition calculated from its serving size.</summary>
public sealed record MealItemResponse(Guid Id, Guid FoodId, string FoodName, decimal Grams, decimal Calories, decimal Protein, decimal Carbs, decimal Fat);
/// <summary>Request to analyze a food image.</summary>
public sealed record AnalyzeScanRequest([param: StringLength(10_000_000)] string? ImageBase64, [param: StringLength(120)] string? IdempotencyKey);
/// <summary>Nutrition estimated from an image, explicitly marked when deterministic fallback was used.</summary>
public sealed record ScanResponse(Guid Id, string FoodName, decimal EstimatedGrams, decimal Calories, decimal Protein, decimal Carbs, decimal Fat, bool IsFallbackEstimate, DateTimeOffset CreatedAt);
/// <summary>Daily nutrition totals and target.</summary>
public sealed record NutritionSummaryResponse(DateOnly Date, decimal Calories, decimal Protein, decimal Carbs, decimal Fat, decimal? CalorieTarget, decimal? ProteinTarget, decimal? CarbsTarget, decimal? FatTarget);
/// <summary>Daily calorie and macro target.</summary>
public sealed record CalorieTargetResponse(DateOnly Date, decimal Calories, decimal Protein, decimal Carbs, decimal Fat, string Source);
