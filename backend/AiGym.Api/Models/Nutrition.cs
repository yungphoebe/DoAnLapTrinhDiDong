namespace AiGym.Api.Models;

public sealed class Food
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string? Brand { get; set; }
    public decimal CaloriesPer100g { get; set; }
    public decimal ProteinPer100g { get; set; }
    public decimal CarbsPer100g { get; set; }
    public decimal FatPer100g { get; set; }
}

public sealed class Meal
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser User { get; set; } = null!;
    public DateTimeOffset ConsumedAt { get; set; }
    public string Name { get; set; } = string.Empty;
    public ICollection<MealItem> Items { get; set; } = new List<MealItem>();
    public decimal Calories { get; set; }
    public decimal Protein { get; set; }
    public decimal Carbs { get; set; }
    public decimal Fat { get; set; }
}

public sealed class MealItem
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid MealId { get; set; }
    public Meal Meal { get; set; } = null!;
    public Guid FoodId { get; set; }
    public Food Food { get; set; } = null!;
    public decimal Servings { get; set; }
    public decimal Grams { get; set; }
}

public sealed class DailyCalorieTarget
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser User { get; set; } = null!;
    public DateOnly Date { get; set; }
    public decimal Calories { get; set; }
    public decimal Protein { get; set; }
    public decimal Carbs { get; set; }
    public decimal Fat { get; set; }
    public string Source { get; set; } = "calculated";
}

public sealed class ConfirmedScanResult
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser User { get; set; } = null!;
    public string? IdempotencyKey { get; set; }
    public string FoodName { get; set; } = string.Empty;
    public decimal EstimatedGrams { get; set; }
    public decimal Calories { get; set; }
    public decimal Protein { get; set; }
    public decimal Carbs { get; set; }
    public decimal Fat { get; set; }
    public bool IsFallbackEstimate { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
