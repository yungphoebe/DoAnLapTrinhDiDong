using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AiGym.Api.Services;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

namespace AiGym.Api.Tests;

public sealed class CoachChatTests
{
    [Theory]
    [InlineData("/api/coach/chat")]
    [InlineData("/api/ai/chat")]
    public async Task Chat_WhenModelTimesOut_ReturnsJsonGatewayTimeout(string path)
    {
        using var factory = new ApiFactory();
        using var app = factory.WithWebHostBuilder(builder => builder.ConfigureTestServices(services =>
            services.AddSingleton<ILmStudioService>(new TestAi(true))));
        using var client = app.CreateClient();
        await Authenticate(client);

        var response = await client.PostAsJsonAsync(path, new { message = "Lich tap nguc" });

        Assert.Equal(HttpStatusCode.GatewayTimeout, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.False(string.IsNullOrWhiteSpace(body.GetProperty("message").GetString()));
        if (path == "/api/coach/chat")
            Assert.Empty((await client.GetFromJsonAsync<JsonElement[]>("/api/coach/conversations"))!);
    }

    [Fact]
    public async Task Chat_SecondMessage_PersistsBothTurns()
    {
        using var factory = new ApiFactory();
        using var app = factory.WithWebHostBuilder(builder => builder.ConfigureTestServices(services =>
            services.AddSingleton<ILmStudioService>(new TestAi(false))));
        using var client = app.CreateClient();
        await Authenticate(client);
        var first = await client.PostAsJsonAsync("/api/coach/chat", new { message = "Hi" });
        first.EnsureSuccessStatusCode();
        var conversation = await first.Content.ReadFromJsonAsync<JsonElement>();
        var id = conversation.GetProperty("id").GetGuid();

        var second = await client.PostAsJsonAsync("/api/coach/chat", new { conversationId = id, message = "Lich tap nguc" });

        second.EnsureSuccessStatusCode();
        var body = await second.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(id, body.GetProperty("id").GetGuid());
        Assert.Equal(4, body.GetProperty("messages").GetArrayLength());
        var saved = await client.GetFromJsonAsync<JsonElement[]>("/api/coach/conversations");
        Assert.Equal(4, Assert.Single(saved!).GetProperty("messages").GetArrayLength());
    }

    private static async Task Authenticate(HttpClient client)
    {
        var response = await client.PostAsJsonAsync("/api/auth/register", new
        {
            fullName = "Coach test", email = $"coach-{Guid.NewGuid():N}@example.com", password = "123123123Az!"
        });
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", body.GetProperty("token").GetString());
    }

    private sealed class TestAi(bool timeout) : ILmStudioService
    {
        public Task<string> ChatAsync(string message, CancellationToken cancellationToken, string? context = null) =>
            timeout ? throw new TaskCanceledException("Model timed out") : Task.FromResult("Goi y: chong day 3 hiep.");
    }
}
