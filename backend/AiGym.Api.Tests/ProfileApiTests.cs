using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace AiGym.Api.Tests;

public sealed class ProfileApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public ProfileApiTests(ApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Profile_RequiresAuthentication()
    {
        var client = _factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/profile")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PutAsJsonAsync("/api/profile", new { fullName = "Test" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/profile/workouts", new { })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/profile/workouts")).StatusCode);
    }

    [Fact]
    public async Task Profile_PersistsPerAccount_AfterLogin_AndWorkoutsAreIdempotent()
    {
        var first = _factory.CreateClient();
        var email = await Register(first, "First");
        var fresh = await first.GetFromJsonAsync<JsonElement>("/api/profile");
        Assert.Equal("First", fresh.GetProperty("fullName").GetString());
        Assert.Equal(email, fresh.GetProperty("email").GetString());
        Assert.Equal(JsonValueKind.Null, fresh.GetProperty("heightCm").ValueKind);
        Assert.Equal(0, fresh.GetProperty("workoutSessions").GetInt32());
        Assert.Equal(0, fresh.GetProperty("streakDays").GetInt32());

        (await first.PutAsJsonAsync("/api/profile", new { fullName = "Updated", heightCm = 175, weightKg = 70, age = 30, gender = "Nam", goal = "Tăng cơ", trainingDays = 3, trainingLocation = "Phòng gym", trainingLevel = "Mới bắt đầu" })).EnsureSuccessStatusCode();
        var workout = new { id = Guid.NewGuid(), durationSeconds = 120, startedAt = DateTimeOffset.UtcNow.AddMinutes(-3) };
        (await first.PostAsJsonAsync("/api/profile/workouts", workout)).EnsureSuccessStatusCode();
        (await first.PostAsJsonAsync("/api/profile/workouts", workout)).EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.Conflict, (await first.PostAsJsonAsync("/api/profile/workouts", new { workout.id, durationSeconds = 121, workout.startedAt })).StatusCode);

        var second = _factory.CreateClient();
        await Register(second, "Second");
        var other = await second.GetFromJsonAsync<JsonElement>("/api/profile");
        Assert.Equal("Second", other.GetProperty("fullName").GetString());
        Assert.Equal(0, other.GetProperty("workoutSessions").GetInt32());
        Assert.Equal(JsonValueKind.Null, other.GetProperty("heightCm").ValueKind);
        Assert.Equal(HttpStatusCode.Conflict, (await second.PostAsJsonAsync("/api/profile/workouts", workout)).StatusCode);

        var reconnected = _factory.CreateClient();
        var login = await reconnected.PostAsJsonAsync("/api/auth/login", new { email, password = "123123123Az!" });
        login.EnsureSuccessStatusCode();
        var auth = await login.Content.ReadFromJsonAsync<JsonElement>();
        reconnected.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.GetProperty("token").GetString());
        var saved = await reconnected.GetFromJsonAsync<JsonElement>("/api/profile");
        Assert.Equal("Updated", saved.GetProperty("fullName").GetString());
        Assert.Equal(175, saved.GetProperty("heightCm").GetDouble());
        Assert.Equal(3, saved.GetProperty("trainingDays").GetInt32());
        Assert.Equal(1, saved.GetProperty("workoutSessions").GetInt32());
        Assert.Equal(120, saved.GetProperty("totalWorkoutSeconds").GetInt32());
        Assert.Equal(1, saved.GetProperty("streakDays").GetInt32());
        var me = await reconnected.GetFromJsonAsync<JsonElement>("/api/auth/me");
        Assert.Equal("Updated", me.GetProperty("fullName").GetString());
    }

    [Fact]
    public async Task WorkoutSummary_UsesVietnamDays_AndBreaksStreakAfterMissedDay()
    {
        var client = _factory.CreateClient();
        await Register(client, "Streak");
        var today = new DateTimeOffset(DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).Date, TimeSpan.FromHours(7));
        foreach (var daysAgo in new[] { 1, 2, 4 })
            (await client.PostAsJsonAsync("/api/profile/workouts", new {
                id = Guid.NewGuid(), durationSeconds = 60, startedAt = today.AddDays(-daysAgo).AddMinutes(1).ToUniversalTime()
            })).EnsureSuccessStatusCode();
        var summary = await client.GetFromJsonAsync<JsonElement>("/api/profile");
        Assert.Equal(3, summary.GetProperty("workoutSessions").GetInt32());
        Assert.Equal(180, summary.GetProperty("totalWorkoutSeconds").GetInt32());
        Assert.Equal(0, summary.GetProperty("todayWorkoutSeconds").GetInt32());
        Assert.Equal(2, summary.GetProperty("streakDays").GetInt32());

        var inactive = _factory.CreateClient();
        await Register(inactive, "Inactive");
        (await inactive.PostAsJsonAsync("/api/profile/workouts", new {
            id = Guid.NewGuid(), durationSeconds = 60, startedAt = today.AddDays(-2)
        })).EnsureSuccessStatusCode();
        summary = await inactive.GetFromJsonAsync<JsonElement>("/api/profile");
        Assert.Equal(0, summary.GetProperty("streakDays").GetInt32());
    }

    [Fact]
    public async Task Profile_RejectsInvalidMeasurementsScheduleAndWorkouts()
    {
        var client = _factory.CreateClient();
        await Register(client, "Validate");
        foreach (var body in new object[] {
            new { fullName = " " }, new { fullName = "Valid", heightCm = -1 },
            new { fullName = "Valid", weightKg = 0 }, new { fullName = "Valid", age = 200 },
            new { fullName = "Valid", trainingDays = 8 },
            new { fullName = "Valid", trainingDays = 0 },
            new { fullName = "Valid", goal = new string('x', 121) }
        })
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PutAsJsonAsync("/api/profile", body)).StatusCode);
        foreach (var body in new object[] {
            new { id = Guid.Empty, durationSeconds = 60, startedAt = DateTimeOffset.UtcNow.AddMinutes(-2) },
            new { id = Guid.NewGuid(), durationSeconds = 0, startedAt = DateTimeOffset.UtcNow.AddMinutes(-2) },
            new { id = Guid.NewGuid(), durationSeconds = 60, startedAt = DateTimeOffset.UtcNow.AddDays(1) },
            new { id = Guid.NewGuid(), durationSeconds = 3600, startedAt = DateTimeOffset.UtcNow.AddMinutes(-2) }
        })
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/profile/workouts", body)).StatusCode);
    }

    [Fact]
    public async Task WorkoutHistory_PersistsSummaries_NormalizesRetries_AndIsolatesAccounts()
    {
        var client = _factory.CreateClient();
        await Register(client, "History");
        var id = Guid.NewGuid();
        var startedAt = DateTimeOffset.UtcNow.AddMinutes(-3);
        var exercises = new[] { new { exercise = "squat", reps = 3, correctReps = 2, incorrectReps = 1 }, new { exercise = "pushup", reps = 2, correctReps = 2, incorrectReps = 0 } };
        var feedbackCounts = new Dictionary<string, int> { ["knees_in"] = 2, ["back_bent"] = 1 };
        (await client.PostAsJsonAsync("/api/profile/workouts", new { id, startedAt, durationSeconds = 60, exercises, feedbackCounts })).EnsureSuccessStatusCode();
        (await client.PostAsJsonAsync("/api/profile/workouts", new { id, startedAt, durationSeconds = 60, exercises = exercises.Reverse(), feedbackCounts = feedbackCounts.Reverse().ToDictionary(x => x.Key, x => x.Value) })).EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsJsonAsync("/api/profile/workouts", new { id, startedAt, durationSeconds = 60, exercises })).StatusCode);
        var legacyId = Guid.NewGuid();
        (await client.PostAsJsonAsync("/api/profile/workouts", new { id = legacyId, startedAt = startedAt.AddDays(-1), durationSeconds = 60 })).EnsureSuccessStatusCode();
        var history = await client.GetFromJsonAsync<JsonElement[]>("/api/profile/workouts");
        Assert.Equal(2, history!.Length);
        Assert.Equal(id, history[0].GetProperty("id").GetGuid());
        Assert.Equal(2, history[0].GetProperty("exercises").GetArrayLength());
        Assert.Equal(2, history[0].GetProperty("feedbackCounts").GetProperty("knees_in").GetInt32());
        Assert.Empty(history[1].GetProperty("exercises").EnumerateArray());
        Assert.Empty(history[1].GetProperty("feedbackCounts").EnumerateObject());
        var other = _factory.CreateClient();
        await Register(other, "Other history");
        Assert.Empty((await other.GetFromJsonAsync<JsonElement[]>("/api/profile/workouts"))!);
    }

    [Fact]
    public async Task WorkoutHistory_ReturnsOnlyLatestFifty()
    {
        var client = _factory.CreateClient();
        await Register(client, "History cap");
        var latest = DateTimeOffset.UtcNow.AddMinutes(-2);
        for (var i = 0; i < 51; i++)
            (await client.PostAsJsonAsync("/api/profile/workouts", new {
                id = Guid.NewGuid(), startedAt = latest.AddMinutes(-i), durationSeconds = 1
            })).EnsureSuccessStatusCode();
        var history = await client.GetFromJsonAsync<JsonElement[]>("/api/profile/workouts");
        Assert.Equal(50, history!.Length);
        Assert.Equal(latest, history[0].GetProperty("startedAt").GetDateTimeOffset());
        Assert.Equal(latest.AddMinutes(-49), history[^1].GetProperty("startedAt").GetDateTimeOffset());
    }

    [Fact]
    public async Task WorkoutSummary_RejectsInvalidCountsExercisesAndFeedback()
    {
        var client = _factory.CreateClient();
        await Register(client, "Summary validation");
        foreach (var exercises in new object[] {
            new[] { new { exercise = "unknown", reps = 1, correctReps = 1, incorrectReps = 0 } },
            new[] { new { exercise = "squat", reps = 2, correctReps = 1, incorrectReps = 0 } },
            new[] { new { exercise = "squat", reps = -1, correctReps = -1, incorrectReps = 0 } },
            new[] { new { exercise = "squat", reps = 100001, correctReps = 100001, incorrectReps = 0 } },
            new[] { new { exercise = "squat", reps = 0, correctReps = 0, incorrectReps = 0 }, new { exercise = "squat", reps = 0, correctReps = 0, incorrectReps = 0 } },
            new object?[] { null }
        })
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/profile/workouts", new { id = Guid.NewGuid(), startedAt = DateTimeOffset.UtcNow.AddMinutes(-2), durationSeconds = 60, exercises })).StatusCode);
        foreach (var feedbackCounts in new[] {
            new Dictionary<string, int> { ["rule"] = -1 }, new Dictionary<string, int> { [" "] = 1 },
            new Dictionary<string, int> { [new string('x', 81)] = 1 },
            Enumerable.Range(0, 21).ToDictionary(x => $"rule{x}", _ => 1)
        })
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/profile/workouts", new { id = Guid.NewGuid(), startedAt = DateTimeOffset.UtcNow.AddMinutes(-2), durationSeconds = 60, feedbackCounts })).StatusCode);
    }

    private static async Task<string> Register(HttpClient client, string name)
    {
        var email = $"profile-{Guid.NewGuid():N}@example.com";
        var response = await client.PostAsJsonAsync("/api/auth/register", new { fullName = name, email, password = "123123123Az!" });
        response.EnsureSuccessStatusCode();
        var auth = await response.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.GetProperty("token").GetString());
        return email;
    }
}

