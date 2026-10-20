using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace AiGym.Api.Tests;

public sealed class WorkoutPlanningApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public WorkoutPlanningApiTests(ApiFactory factory) => _factory = factory;

    [Fact]
    public async Task PlansAndAppointments_AreScopedToOwner()
    {
        var owner = await AuthenticatedClient("plan-owner");
        var exercises = await owner.GetFromJsonAsync<JsonElement[]>("/api/exercises");
        Assert.NotNull(exercises);
        var exerciseId = exercises[0].GetProperty("id").GetInt32();
        var created = await owner.PostAsJsonAsync("/api/workout-plans", new
        {
            name = "Strength", goal = "muscle", level = "beginner", isActive = true,
            exercises = new[] { new { exerciseId, sets = 3, reps = 10, restSeconds = 60, order = 0 } }
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var plan = await created.Content.ReadFromJsonAsync<JsonElement>();
        var planId = plan.GetProperty("id").GetGuid();
        Assert.Equal(HttpStatusCode.Created, (await owner.PostAsJsonAsync("/api/appointments", new
        {
            workoutPlanId = planId, startsAt = DateTimeOffset.UtcNow.AddDays(1), durationMinutes = 45
        })).StatusCode);

        var other = await AuthenticatedClient("plan-other");
        Assert.Empty(await other.GetFromJsonAsync<JsonElement[]>("/api/workout-plans") ?? []);
        Assert.Equal(HttpStatusCode.NotFound, await other.GetAsync($"/api/workout-plans/{planId}").ContinueWith(x => x.Result.StatusCode));
    }

    [Fact]
    public async Task WeeklyProgress_ReportsSavedWorkoutsAndPlans()
    {
        var client = await AuthenticatedClient("weekly");
        var monday = DateTimeOffset.UtcNow.Date.AddDays(-(int)DateTimeOffset.UtcNow.DayOfWeek + 1);
        var planResponse = await client.PostAsJsonAsync("/api/workout-plans", new { name = "Weekly", exercises = Array.Empty<object>() });
        var plan = await planResponse.Content.ReadFromJsonAsync<JsonElement>();
        await client.PostAsJsonAsync("/api/appointments", new { workoutPlanId = plan.GetProperty("id").GetGuid(), startsAt = monday.AddHours(10), durationMinutes = 30 });
        await client.PostAsJsonAsync("/api/profile/workouts", new { id = Guid.NewGuid(), durationSeconds = 120, startedAt = monday.AddHours(11) });
        var report = await client.GetFromJsonAsync<JsonElement>("/api/progress/weekly?weekStart=" + monday.ToString("yyyy-MM-dd"));
        Assert.Equal(1, report.GetProperty("plannedWorkouts").GetInt32());
        Assert.Equal(1, report.GetProperty("completedWorkouts").GetInt32());
        Assert.Equal(120, report.GetProperty("totalWorkoutSeconds").GetInt32());
    }

    private async Task<HttpClient> AuthenticatedClient(string prefix)
    {
        var client = _factory.CreateClient();
        var email = $"{prefix}-{Guid.NewGuid():N}@example.com";
        var register = await client.PostAsJsonAsync("/api/auth/register", new { fullName = prefix, email, password = "123123123Az!" });
        register.EnsureSuccessStatusCode();
        var auth = await register.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.GetProperty("token").GetString());
        return client;
    }
}
