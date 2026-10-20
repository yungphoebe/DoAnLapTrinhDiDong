using System.Security.Claims;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

[ApiController, Authorize, Route("api/nutrition")]
public sealed class NutritionController(ApplicationDbContext db) : ControllerBase
{
    private string? UserId => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");

    [HttpGet("foods")]
    public async Task<ActionResult<IReadOnlyList<FoodResponse>>> SearchFoods([FromQuery] string? query, CancellationToken ct)
    {
        var foods = db.Foods.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(query)) foods = foods.Where(x => x.Name.Contains(query.Trim()));
        return Ok(await foods.OrderBy(x => x.Name).Take(50).Select(x => new FoodResponse(x.Id, x.Name, x.Brand, x.CaloriesPer100g, x.ProteinPer100g, x.CarbsPer100g, x.FatPer100g)).ToListAsync(ct));
    }

    [HttpPost("scans/analyze")]
    public async Task<ActionResult<ScanResponse>> Analyze(AnalyzeScanRequest request, CancellationToken ct)
    {
        var userId = UserId;
        if (userId is null) return Unauthorized();
        if (request.ImageBase64 is null || request.ImageBase64.Length == 0) return BadRequest(new { message = "ImageBase64 is required." });
        if (!string.IsNullOrWhiteSpace(request.IdempotencyKey))
        {
            var prior = await db.ConfirmedScanResults.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == userId && x.IdempotencyKey == request.IdempotencyKey, ct);
            if (prior is not null) return Ok(ToScan(prior));
        }
        var result = new ConfirmedScanResult { UserId = userId, IdempotencyKey = request.IdempotencyKey, FoodName = "Estimated meal", EstimatedGrams = 100, Calories = 200, Protein = 10, Carbs = 25, Fat = 7, IsFallbackEstimate = true };
        db.ConfirmedScanResults.Add(result);
        await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(GetScan), new { id = result.Id }, ToScan(result));
    }

    [HttpGet("scans/{id:guid}")]
    public async Task<ActionResult<ScanResponse>> GetScan(Guid id, CancellationToken ct)
    {
        var result = await db.ConfirmedScanResults.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id && x.UserId == UserId, ct);
        return result is null ? NotFound() : Ok(ToScan(result));
    }

    [HttpPost("scans/{id:guid}/confirm")]
    public async Task<ActionResult<ScanResponse>> ConfirmScan(Guid id, CancellationToken ct)
    {
        var result = await db.ConfirmedScanResults.SingleOrDefaultAsync(x => x.Id == id && x.UserId == UserId, ct);
        return result is null ? NotFound() : Ok(ToScan(result));
    }

    [HttpPost("meals")]
    public async Task<ActionResult<MealResponse>> CreateMeal(MealRequest request, CancellationToken ct)
    {
        var meal = await BuildMeal(request, ct);
        if (meal is null) return BadRequest(new { message = "Each food must exist and grams must be positive." });
        meal.UserId = UserId!;
        db.Meals.Add(meal);
        await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(GetMeal), new { id = meal.Id }, ToMeal(meal));
    }

    [HttpGet("meals")]
    public async Task<ActionResult<IReadOnlyList<MealResponse>>> GetMeals([FromQuery] DateOnly? date, CancellationToken ct)
    {
        var query = db.Meals.Include(x => x.Items).ThenInclude(x => x.Food).Where(x => x.UserId == UserId);
        if (date.HasValue) query = query.Where(x => DateOnly.FromDateTime(x.ConsumedAt.UtcDateTime.Date) == date.Value);
        var meals = await query.OrderBy(x => x.ConsumedAt).ToListAsync(ct);
        return Ok(meals.Select(ToMeal).ToList());
    }

    [HttpGet("meals/{id:guid}")]
    public async Task<ActionResult<MealResponse>> GetMeal(Guid id, CancellationToken ct)
    {
        var meal = await db.Meals.Include(x => x.Items).ThenInclude(x => x.Food).SingleOrDefaultAsync(x => x.Id == id && x.UserId == UserId, ct);
        return meal is null ? NotFound() : Ok(ToMeal(meal));
    }

    [HttpPut("meals/{id:guid}")]
    public async Task<ActionResult<MealResponse>> UpdateMeal(Guid id, MealRequest request, CancellationToken ct)
    {
        var meal = await db.Meals.Include(x => x.Items).ThenInclude(x => x.Food).SingleOrDefaultAsync(x => x.Id == id && x.UserId == UserId, ct);
        if (meal is null) return NotFound();
        var replacement = await BuildMeal(request, ct);
        if (replacement is null) return BadRequest(new { message = "Each food must exist and grams must be positive." });
        meal.Name = replacement.Name; meal.ConsumedAt = replacement.ConsumedAt; meal.Items = replacement.Items; Recalculate(meal);
        await db.SaveChangesAsync(ct);
        return Ok(ToMeal(meal));
    }

    [HttpDelete("meals/{id:guid}")]
    public async Task<IActionResult> DeleteMeal(Guid id, CancellationToken ct)
    {
        var meal = await db.Meals.SingleOrDefaultAsync(x => x.Id == id && x.UserId == UserId, ct);
        if (meal is null) return NotFound();
        db.Meals.Remove(meal); await db.SaveChangesAsync(ct); return NoContent();
    }

    [HttpGet("summary")]
    public async Task<ActionResult<NutritionSummaryResponse>> Summary([FromQuery] DateOnly? date, CancellationToken ct)
    {
        var day = date ?? DateOnly.FromDateTime(DateTime.UtcNow.Date);
        var meals = await db.Meals.Include(x => x.Items).Where(x => x.UserId == UserId && DateOnly.FromDateTime(x.ConsumedAt.UtcDateTime.Date) == day).ToListAsync(ct);
        var target = await db.DailyCalorieTargets.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == UserId && x.Date == day, ct);
        return Ok(new NutritionSummaryResponse(day, meals.Sum(x => x.Calories), meals.Sum(x => x.Protein), meals.Sum(x => x.Carbs), meals.Sum(x => x.Fat), target?.Calories, target?.Protein, target?.Carbs, target?.Fat));
    }

    [HttpPost("target/calculate")]
    public async Task<ActionResult<CalorieTargetResponse>> CalculateTarget(CancellationToken ct)
    {
        var user = await db.Users.SingleOrDefaultAsync(x => x.Id == UserId, ct);
        if (user?.WeightKg is null || user.HeightCm is null || user.Age is null) return BadRequest(new { message = "Complete height, weight and age in your profile first." });
        var bmr = 10 * (decimal)user.WeightKg.Value + 6.25m * (decimal)user.HeightCm.Value - 5 * user.Age.Value + (user.Gender?.Equals("female", StringComparison.OrdinalIgnoreCase) == true ? -161 : 5);
        var calories = Math.Round(bmr * 1.45m + (user.Goal?.Contains("lose", StringComparison.OrdinalIgnoreCase) == true ? -300 : user.Goal?.Contains("gain", StringComparison.OrdinalIgnoreCase) == true ? 250 : 0));
        var date = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        var target = await db.DailyCalorieTargets.SingleOrDefaultAsync(x => x.UserId == UserId && x.Date == date, ct) ?? new DailyCalorieTarget { UserId = UserId!, Date = date };
        target.Calories = calories; target.Protein = Math.Round((decimal)user.WeightKg.Value * 1.6m); target.Carbs = Math.Round(calories * .45m / 4); target.Fat = Math.Round(calories * .25m / 9); target.Source = "calculated";
        if (target.Id == Guid.Empty) db.DailyCalorieTargets.Add(target); else if (db.Entry(target).State == EntityState.Detached) db.DailyCalorieTargets.Add(target);
        await db.SaveChangesAsync(ct);
        return Ok(new CalorieTargetResponse(date, target.Calories, target.Protein, target.Carbs, target.Fat, target.Source));
    }

    [HttpGet("target")]
    public async Task<ActionResult<CalorieTargetResponse>> GetTarget([FromQuery] DateOnly? date, CancellationToken ct)
    {
        var day = date ?? DateOnly.FromDateTime(DateTime.UtcNow.Date);
        var target = await db.DailyCalorieTargets.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == UserId && x.Date == day, ct);
        return target is null ? NotFound() : Ok(new CalorieTargetResponse(target.Date, target.Calories, target.Protein, target.Carbs, target.Fat, target.Source));
    }

    private async Task<Meal?> BuildMeal(MealRequest request, CancellationToken ct)
    {
        if (request.Items.Length == 0 || request.Items.Any(x => x.Grams <= 0)) return null;
        var ids = request.Items.Select(x => x.FoodId).Distinct().ToArray();
        var foods = await db.Foods.Where(x => ids.Contains(x.Id)).ToDictionaryAsync(x => x.Id, ct);
        if (foods.Count != ids.Length) return null;
        var meal = new Meal { Name = request.Name.Trim(), ConsumedAt = request.ConsumedAt.ToUniversalTime() };
        foreach (var item in request.Items) meal.Items.Add(new MealItem { FoodId = item.FoodId, Food = foods[item.FoodId], Grams = item.Grams, Servings = item.Grams / 100 });
        Recalculate(meal); return meal;
    }
    private static void Recalculate(Meal meal) { meal.Calories = meal.Items.Sum(i => i.Food.CaloriesPer100g * i.Grams / 100); meal.Protein = meal.Items.Sum(i => i.Food.ProteinPer100g * i.Grams / 100); meal.Carbs = meal.Items.Sum(i => i.Food.CarbsPer100g * i.Grams / 100); meal.Fat = meal.Items.Sum(i => i.Food.FatPer100g * i.Grams / 100); }
    private static MealResponse ToMeal(Meal x) => new(x.Id, x.Name, x.ConsumedAt, x.Calories, x.Protein, x.Carbs, x.Fat, x.Items.Select(i => new MealItemResponse(i.Id, i.FoodId, i.Food.Name, i.Grams, i.Food.CaloriesPer100g * i.Grams / 100, i.Food.ProteinPer100g * i.Grams / 100, i.Food.CarbsPer100g * i.Grams / 100, i.Food.FatPer100g * i.Grams / 100)).ToList());
    private static ScanResponse ToScan(ConfirmedScanResult x) => new(x.Id, x.FoodName, x.EstimatedGrams, x.Calories, x.Protein, x.Carbs, x.Fat, x.IsFallbackEstimate, x.CreatedAt);
}
