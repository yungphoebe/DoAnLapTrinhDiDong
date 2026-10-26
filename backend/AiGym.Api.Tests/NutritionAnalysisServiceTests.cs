using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AiGym.Api.Dtos;
using AiGym.Api.Options;
using AiGym.Api.Services;
using Microsoft.Extensions.Options;

namespace AiGym.Api.Tests;

public sealed class NutritionAnalysisServiceTests
{
    private const string Image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=";

    [Fact]
    public async Task ForwardsImageAndReturnsWholePortionNutrition()
    {
        var handler = new Handler("""{"isFood":true,"foodName":"Cơm gà","estimatedGrams":350,"calories":600,"protein":35,"carbs":70,"fat":20}""");
        var result = await Service(handler).AnalyzeAsync(new AnalyzeScanRequest(Image, null, "image/png"), default);
        Assert.Equal(600, result.Calories);
        Assert.Equal("Cơm gà", result.FoodName);
        Assert.False(result.IsFallbackEstimate);
        Assert.Equal("/api/v1/chat", handler.Path);
        var body = handler.Request;
        Assert.Equal("off", body.GetProperty("reasoning").GetString());
        Assert.False(body.GetProperty("store").GetBoolean());
        Assert.Equal("image", body.GetProperty("input")[1].GetProperty("type").GetString());
        Assert.Equal($"data:image/png;base64,{Image}", body.GetProperty("input")[1].GetProperty("data_url").GetString());
    }

    [Theory]
    [InlineData("{}")]
    [InlineData("not JSON")]
    [InlineData("""{"isFood":true,"foodName":"Rice","estimatedGrams":100,"calories":-1,"protein":2,"carbs":20,"fat":1}""")]
    [InlineData("""{"isFood":true,"foodName":"Rice","estimatedGrams":100,"calories":100,"carbs":20,"fat":1}""")]
    public async Task RejectsInvalidOrIncompleteModelData(string answer)
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Service(new Handler(answer)).AnalyzeAsync(new AnalyzeScanRequest(Image, null), default));
    }

    [Fact]
    public async Task RejectsNonFoodImage()
    {
        await Assert.ThrowsAsync<ArgumentException>(() =>
            Service(new Handler("""{"isFood":false}""")).AnalyzeAsync(new AnalyzeScanRequest(Image, null), default));
    }

    [Theory]
    [InlineData("not-image", null)]
    [InlineData("YWJjZA==", "image/png")]
    [InlineData(Image, "image/jpeg")]
    public async Task RejectsInvalidImageBeforeCallingModel(string image, string? mime)
    {
        var handler = new Handler("{}");
        await Assert.ThrowsAsync<ArgumentException>(() => Service(handler).AnalyzeAsync(new AnalyzeScanRequest(image, null, mime), default));
        Assert.Null(handler.Path);
    }

    private static NutritionAnalysisService Service(Handler handler) => new(
        new HttpClient(handler) { BaseAddress = new Uri("http://localhost:1234") },
        Microsoft.Extensions.Options.Options.Create(new LmStudioOptions { Model = "vision" }));

    private sealed class Handler(string answer) : HttpMessageHandler
    {
        public string? Path { get; private set; }
        public JsonElement Request { get; private set; }
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Path = request.RequestUri!.AbsolutePath;
            Request = await request.Content!.ReadFromJsonAsync<JsonElement>(cancellationToken);
            return new HttpResponseMessage(HttpStatusCode.OK) {
                Content = JsonContent.Create(new { output = new[] { new { type = "message", content = answer } } }) };
        }
    }
}

