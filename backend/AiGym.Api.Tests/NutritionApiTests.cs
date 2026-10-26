using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AiGym.Api.Services;
using Microsoft.Extensions.DependencyInjection;

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
    public async Task InvalidImageIsRejectedInsteadOfInventingNutrition()
    {
        var client = await AuthenticatedClient();
        var request = new { imageBase64 = "not-an-image", idempotencyKey = Guid.NewGuid().ToString() };
        var first = await client.PostAsJsonAsync("/api/nutrition/scans/analyze", request);
        Assert.Equal(System.Net.HttpStatusCode.BadRequest, first.StatusCode);
    }

    [Fact]
    public async Task CustomMealPreservesMacrosWithoutAddingGlobalFood()
    {
        var client = await AuthenticatedClient();
        var name = $"Scanned dish {Guid.NewGuid():N}";
        object Payload(decimal calories) => new { name = "Lunch", consumedAt = DateTimeOffset.UtcNow,
            items = new[] { new { name, grams = 350m, calories, protein = 30m, carbs = 70m, fat = 20m } } };
        var create = await client.PostAsJsonAsync("/api/nutrition/meals", Payload(580m));
        Assert.Equal(System.Net.HttpStatusCode.Created, create.StatusCode);
        var meal = await create.Content.ReadFromJsonAsync<JsonElement>();
        var id = meal.GetProperty("id").GetGuid();
        Assert.Equal(580m, meal.GetProperty("calories").GetDecimal());
        Assert.Equal(JsonValueKind.Null, meal.GetProperty("items")[0].GetProperty("foodId").ValueKind);
        var update = await client.PutAsJsonAsync($"/api/nutrition/meals/{id}", Payload(600m));
        Assert.Equal(System.Net.HttpStatusCode.OK, update.StatusCode);
        var saved = await client.GetFromJsonAsync<JsonElement>($"/api/nutrition/meals/{id}");
        Assert.Equal(600m, saved.GetProperty("calories").GetDecimal());
        Assert.Equal(name, saved.GetProperty("items")[0].GetProperty("foodName").GetString());
        var summary = await client.GetFromJsonAsync<JsonElement>("/api/nutrition/summary");
        Assert.Equal(600m, summary.GetProperty("calories").GetDecimal());
        var foods = await client.GetFromJsonAsync<JsonElement[]>($"/api/nutrition/foods?query={Uri.EscapeDataString(name)}");
        Assert.Empty(foods!);
        var other = await AuthenticatedClient();
        Assert.Equal(System.Net.HttpStatusCode.NotFound, (await other.GetAsync($"/api/nutrition/meals/{id}")).StatusCode);
        Assert.Equal(System.Net.HttpStatusCode.NotFound, (await other.PutAsJsonAsync($"/api/nutrition/meals/{id}", Payload(100m))).StatusCode);
    }

    [Fact]
    public async Task ScanUsesModelResultIsIdempotentAndOwned()
    {
        using var factory = _factory.WithWebHostBuilder(builder => builder.ConfigureServices(services =>
            services.AddHttpClient<INutritionAnalysisService, NutritionAnalysisService>()
                .ConfigurePrimaryHttpMessageHandler(() => new NutritionHandler())));
        var client = await AuthenticatedClient(factory.CreateClient());
        var request = new {
            imageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
            mimeType = "image/png", idempotencyKey = Guid.NewGuid().ToString()
        };
        var first = await client.PostAsJsonAsync("/api/nutrition/scans/analyze", request);
        Assert.Equal(System.Net.HttpStatusCode.Created, first.StatusCode);
        var scan = await first.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(580m, scan.GetProperty("calories").GetDecimal());
        Assert.False(scan.GetProperty("isFallbackEstimate").GetBoolean());
        var second = await client.PostAsJsonAsync("/api/nutrition/scans/analyze", request);
        Assert.Equal(System.Net.HttpStatusCode.OK, second.StatusCode);
        var repeated = await second.Content.ReadFromJsonAsync<JsonElement>();
        var id = scan.GetProperty("id").GetGuid();
        Assert.Equal(id, repeated.GetProperty("id").GetGuid());
        var other = await AuthenticatedClient(factory.CreateClient());
        Assert.Equal(System.Net.HttpStatusCode.NotFound, (await other.GetAsync($"/api/nutrition/scans/{id}")).StatusCode);
    }

    private sealed class NutritionHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) =>
            Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK) {
                Content = JsonContent.Create(new { output = new[] { new { type = "message",
                    content = """{"isFood":true,"foodName":"Cơm gà","estimatedGrams":350,"calories":580,"protein":30,"carbs":70,"fat":20}""" } } }) });
    }

    private async Task<HttpClient> AuthenticatedClient(HttpClient? suppliedClient = null)
    {
        var client = suppliedClient ?? _factory.CreateClient();
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
