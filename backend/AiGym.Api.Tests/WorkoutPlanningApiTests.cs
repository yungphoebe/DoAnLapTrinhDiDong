using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AiGym.Api.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

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
        var monday = DateTimeOffset.UtcNow.Date.AddDays(-(((int)DateTimeOffset.UtcNow.DayOfWeek + 6) % 7));
        var planResponse = await client.PostAsJsonAsync("/api/workout-plans", new { name = "Weekly", exercises = Array.Empty<object>() });
        var plan = await planResponse.Content.ReadFromJsonAsync<JsonElement>();
        await client.PostAsJsonAsync("/api/appointments", new { workoutPlanId = plan.GetProperty("id").GetGuid(), startsAt = monday.AddHours(10), durationMinutes = 30 });
        await client.PostAsJsonAsync("/api/profile/workouts", new { id = Guid.NewGuid(), durationSeconds = 120, startedAt = monday.AddHours(11) });
        var report = await client.GetFromJsonAsync<JsonElement>("/api/progress/weekly?weekStart=" + monday.ToString("yyyy-MM-dd"));
        Assert.Equal(1, report.GetProperty("plannedWorkouts").GetInt32());
        Assert.Equal(1, report.GetProperty("completedWorkouts").GetInt32());
        Assert.Equal(120, report.GetProperty("totalWorkoutSeconds").GetInt32());
    }

    [Fact]
    public async Task PlannedExerciseResult_IsLinkedToOwnedPlanExercise_AndRetainsHistoryOnEdit()
    {
        var owner = await AuthenticatedClient("plan-result-owner");
        var catalog = await owner.GetFromJsonAsync<JsonElement[]>("/api/exercises");
        var exerciseId = catalog![0].GetProperty("id").GetInt32();
        var created = await owner.PostAsJsonAsync("/api/workout-plans", new
        {
            name = "Plan result",
            goal = "strength",
            level = "beginner",
            daysPerWeek = 3,
            sessionMinutes = 45,
            trainingLocation = "home",
            equipment = "mat",
            isActive = true,
            exercises = new[]
            {
                new { exerciseId, dayNumber = 2, sets = 3, reps = 12, targetSeconds = (int?)null, restSeconds = 60, order = 0 }
            }
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var plan = await created.Content.ReadFromJsonAsync<JsonElement>();
        var planId = plan.GetProperty("id").GetGuid();
        var item = plan.GetProperty("exercises")[0];
        var planExerciseId = item.GetProperty("id").GetGuid();
        Assert.Equal(2, item.GetProperty("dayNumber").GetInt32());
        Assert.Equal(12, item.GetProperty("reps").GetInt32());

        var resultId = Guid.NewGuid();
        var resultPath = $"/api/workout-plans/{planId}/exercises/{planExerciseId}/results";
        var startedAt = DateTimeOffset.UtcNow.AddMinutes(-8);
        var invalid = await owner.PostAsJsonAsync(resultPath, new
        {
            id = resultId,
            startedAt,
            durationSeconds = 420,
            actualSets = 2,
            actualReps = 24,
            completed = true
        });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);

        var saved = await owner.PostAsJsonAsync(resultPath, new
        {
            id = resultId,
            startedAt,
            durationSeconds = 420,
            actualSets = 3,
            actualReps = 36,
            completed = true,
            feedbackCounts = new Dictionary<string, int> { ["squat_torso_lean"] = 1 }
        });
        Assert.Equal(HttpStatusCode.Created, saved.StatusCode);

        var loaded = await owner.GetFromJsonAsync<JsonElement>($"/api/workout-plans/{planId}");
        Assert.Equal(resultId, loaded.GetProperty("exercises")[0].GetProperty("results")[0]
            .GetProperty("id").GetGuid());
        Assert.True(loaded.GetProperty("exercises")[0].GetProperty("results")[0]
            .GetProperty("completed").GetBoolean());

        var edited = await owner.PutAsJsonAsync($"/api/workout-plans/{planId}", new
        {
            name = "Plan result edited",
            goal = "strength",
            level = "beginner",
            daysPerWeek = 4,
            sessionMinutes = 50,
            trainingLocation = "gym",
            equipment = "barbell",
            isActive = true,
            exercises = new[]
            {
                new { id = planExerciseId, exerciseId, dayNumber = 3, sets = 4, reps = 10, restSeconds = 60, order = 0 }
            }
        });
        Assert.Equal(HttpStatusCode.OK, edited.StatusCode);
        var editedPlan = await edited.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(planExerciseId, editedPlan.GetProperty("exercises")[0].GetProperty("id").GetGuid());
        Assert.Equal(1, editedPlan.GetProperty("exercises")[0].GetProperty("results").GetArrayLength());

        var other = await AuthenticatedClient("plan-result-other");
        Assert.Equal(HttpStatusCode.NotFound, await other.PostAsJsonAsync(resultPath, new
        {
            id = Guid.NewGuid(),
            startedAt,
            durationSeconds = 10,
            actualSets = 0,
            actualReps = 0,
            completed = false
        }).ContinueWith(task => task.Result.StatusCode));
    }

    [Fact]
    public async Task AiPlanProposal_UsesCatalogIds_AndRejectsUnknownExercises()
    {
        using var goodFactory = _factory.WithWebHostBuilder(builder =>
            builder.ConfigureTestServices(services =>
                services.AddSingleton<ILmStudioService>(new FixedAi(
                    """{"name":"Lịch cơ bản","exercises":[{"exerciseId":1,"dayNumber":1,"sets":3,"reps":10,"targetSeconds":null,"restSeconds":60,"order":0}]}"""))));
        var client = await AuthenticatedClient(goodFactory.CreateClient(), "proposal-good");
        var response = await client.PostAsJsonAsync("/api/workout-plans/proposal", new
        {
            goal = "fitness",
            level = "beginner",
            daysPerWeek = 1,
            sessionMinutes = 45,
            trainingLocation = "home",
            equipment = ""
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var proposal = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(1, proposal.GetProperty("exercises")[0].GetProperty("exerciseId").GetInt32());
        Assert.False(string.IsNullOrWhiteSpace(
            proposal.GetProperty("exercises")[0].GetProperty("exerciseName").GetString()));

        using var badFactory = _factory.WithWebHostBuilder(builder =>
            builder.ConfigureTestServices(services =>
                services.AddSingleton<ILmStudioService>(new FixedAi(
                    """{"name":"Lịch sai","exercises":[{"exerciseId":999999,"dayNumber":1,"sets":3,"reps":10,"targetSeconds":null,"restSeconds":60,"order":0}]}"""))));
        var badClient = await AuthenticatedClient(badFactory.CreateClient(), "proposal-bad");
        var invalid = await badClient.PostAsJsonAsync("/api/workout-plans/proposal", new
        {
            goal = "fitness",
            level = "beginner",
            daysPerWeek = 1,
            sessionMinutes = 45,
            trainingLocation = "home"
        });
        Assert.Equal(HttpStatusCode.BadGateway, invalid.StatusCode);
    }

    private static async Task<HttpClient> AuthenticatedClient(HttpClient client, string prefix)
    {
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

    private sealed class FixedAi(string response) : ILmStudioService
    {
        public Task<string> ChatAsync(
            string message,
            CancellationToken cancellationToken,
            string? context = null,
            int maxOutputTokens = 256) =>
            Task.FromResult(response);
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
