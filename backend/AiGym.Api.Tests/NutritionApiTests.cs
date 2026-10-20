using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace AiGym.Api.Tests;

public sealed class NutritionApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public NutritionApiTests(ApiFactory factory) => _factory = factory;

    [Fact]
    public async Task MealTotalsAreRecalculatedAndSummaryIsOwned()
    {
        var client = await AuthenticatedClient();
        var foods = await client.GetFromJsonAsync<JsonElement[]>("/api/nutrition/foods?query=rice");
        Assert.NotNull(foods);
        var foodId = foods[0].GetProperty("id").GetGuid();
        var create = await client.PostAsJsonAsync("/api/nutrition/meals", new
        {
            name = "Lunch", consumedAt = DateTimeOffset.UtcNow,
            items = new[] { new { foodId, grams = 200m } }
        });
        Assert.Equal(System.Net.HttpStatusCode.Created, create.StatusCode);
        var meal = await create.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(260m, meal.GetProperty("calories").GetDecimal());
        var summary = await client.GetFromJsonAsync<JsonElement>("/api/nutrition/summary");
        Assert.Equal(260m, summary.GetProperty("calories").GetDecimal());
    }

    [Fact]
    public async Task ScanRequestIsIdempotentAndClearlyMarksFallback()
    {
        var client = await AuthenticatedClient();
        var request = new { imageBase64 = "not-an-image", idempotencyKey = Guid.NewGuid().ToString() };
        var first = await client.PostAsJsonAsync("/api/nutrition/scans/analyze", request);
        var second = await client.PostAsJsonAsync("/api/nutrition/scans/analyze", request);
        Assert.Equal(System.Net.HttpStatusCode.Created, first.StatusCode);
        Assert.Equal(System.Net.HttpStatusCode.OK, second.StatusCode);
        var a = await first.Content.ReadFromJsonAsync<JsonElement>();
        var b = await second.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(a.GetProperty("id").GetGuid(), b.GetProperty("id").GetGuid());
        Assert.True(a.GetProperty("isFallbackEstimate").GetBoolean());
    }

    private async Task<HttpClient> AuthenticatedClient()
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/register", new
        {
            fullName = "Nutrition User",
            email = $"nutrition-{Guid.NewGuid():N}@example.com",
            password = "123123123Az!"
        });
        var auth = await response.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.GetProperty("token").GetString());
        return client;
    }
}
