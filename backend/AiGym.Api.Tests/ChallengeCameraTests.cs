using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace AiGym.Api.Tests;

public sealed class ChallengeCameraTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public ChallengeCameraTests(ApiFactory factory) => _factory = factory;

    [Fact]
    public async Task CameraWorkout_AddsCorrectRepsAndSessions_AndManualProgressIsGone()
    {
        var client = _factory.CreateClient();
        await Register(client);
        foreach (var id in new[] { "c1", "c3", "c4" })
            (await client.PostAsync($"/api/challenges/{id}/join", null)).EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.NotFound,
            (await client.PostAsJsonAsync("/api/challenges/c3/progress", new { amount = 300 })).StatusCode);

        var workout = new
        {
            id = Guid.NewGuid(),
            startedAt = DateTimeOffset.UtcNow.AddMinutes(-3),
            durationSeconds = 60,
            exercises = new[] { new { exercise = "squat", reps = 12, correctReps = 10, incorrectReps = 2 } }
        };
        (await client.PostAsJsonAsync("/api/profile/workouts", workout)).EnsureSuccessStatusCode();
        (await client.PostAsJsonAsync("/api/profile/workouts", workout)).EnsureSuccessStatusCode(); // retry must not double count

        var list = await client.GetFromJsonAsync<JsonElement[]>("/api/challenges");
        int Today(string id) => list!.Single(x => x.GetProperty("id").GetString() == id).GetProperty("today_amount").GetInt32();
        Assert.Equal(1, Today("c1"));
        Assert.Equal(10, Today("c3"));
        Assert.Equal(0, Today("c4"));
    }

    private static async Task Register(HttpClient client)
    {
        var email = $"challenge-{Guid.NewGuid():N}@example.com";
        var response = await client.PostAsJsonAsync("/api/auth/register", new { fullName = "Cam", email, password = "123123123Az!" });
        response.EnsureSuccessStatusCode();
        var auth = await response.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.GetProperty("token").GetString());
    }
}
