using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace AiGym.Api.Tests;

public sealed class ActivityTrackingApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;

    public ActivityTrackingApiTests(ApiFactory factory) => _factory = factory;

    [Fact]
    public async Task ActivitySessionsAndGoals_AreOwnedAndAggregateWithoutDoubleCounting()
    {
        var owner = await AuthenticatedClient("activity-owner");
        var other = await AuthenticatedClient("activity-other");
        var now = DateTimeOffset.UtcNow;
        var day = now.ToOffset(TimeSpan.FromHours(7)).ToString("yyyy-MM-dd");
        var id = Guid.NewGuid();

        var save = await owner.PostAsJsonAsync("/api/activity/sessions", new
        {
            id,
            activityType = "walking",
            startedAt = now.AddMinutes(-20),
            durationSeconds = 1200,
            steps = 600,
            distanceMeters = 850.5,
            route = new[]
            {
                new { latitude = 10.77, longitude = 106.69, recordedAt = now.AddMinutes(-20), segmentStart = true },
                new { latitude = 10.771, longitude = 106.691, recordedAt = now.AddMinutes(-19), segmentStart = false }
            },
            distanceEstimated = false,
            completed = true
        });
        Assert.Equal(HttpStatusCode.Created, save.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await owner.PostAsJsonAsync("/api/activity/sessions", new
        {
            id,
            activityType = "walking",
            startedAt = now.AddMinutes(-20),
            durationSeconds = 1200,
            steps = 600,
            distanceMeters = 850.5,
            route = new[]
            {
                new { latitude = 10.77, longitude = 106.69, recordedAt = now.AddMinutes(-20), segmentStart = true },
                new { latitude = 10.771, longitude = 106.691, recordedAt = now.AddMinutes(-19), segmentStart = false }
            },
            distanceEstimated = false,
            completed = true
        })).StatusCode);

        var goal = await owner.PutAsJsonAsync($"/api/activity/goals/{day}", new
        {
            stepsGoal = 1000,
            minutesGoal = 30,
            distanceGoalKm = 2.0
        });
        Assert.Equal(HttpStatusCode.OK, goal.StatusCode);
        var progress = await goal.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(600, progress.GetProperty("steps").GetInt32());
        Assert.Equal(20, progress.GetProperty("minutes").GetInt32());
        Assert.Equal(0.8505, progress.GetProperty("distanceKm").GetDouble(), 3);
        var saved = await owner.GetFromJsonAsync<JsonElement>("/api/activity/sessions");
        var route = saved[0].GetProperty("route");
        Assert.Equal(2, route.GetArrayLength());
        Assert.True(route[0].GetProperty("segmentStart").GetBoolean());

        Assert.Equal(HttpStatusCode.NotFound, (await other.PostAsJsonAsync("/api/activity/sessions", new
        {
            id,
            activityType = "running",
            startedAt = now.AddMinutes(-10),
            durationSeconds = 100,
            steps = 1,
            distanceMeters = (double?)null,
            distanceEstimated = false,
            completed = false
        })).StatusCode);

        var invalidRoute = await owner.PostAsJsonAsync("/api/activity/sessions", new
        {
            id = Guid.NewGuid(),
            activityType = "running",
            startedAt = now,
            durationSeconds = 60,
            steps = (int?)null,
            distanceMeters = (double?)null,
            route = new[] { new { latitude = 100.0, longitude = 0.0, recordedAt = now, segmentStart = true } },
            distanceEstimated = false,
            completed = true
        });
        Assert.Equal(HttpStatusCode.BadRequest, invalidRoute.StatusCode);
    }

    private async Task<HttpClient> AuthenticatedClient(string prefix)
    {
        var client = _factory.CreateClient();
        var email = $"{prefix}-{Guid.NewGuid():N}@example.com";
        var register = await client.PostAsJsonAsync("/api/auth/register", new
        {
            fullName = prefix,
            email,
            password = "123123123Az!"
        });
        register.EnsureSuccessStatusCode();
        var auth = await register.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", auth.GetProperty("token").GetString());
        return client;
    }
}
