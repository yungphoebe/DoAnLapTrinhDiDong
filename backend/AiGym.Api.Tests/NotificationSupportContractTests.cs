using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace AiGym.Api.Tests;

public sealed class NotificationSupportContractTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task InboxPaginationAndReadAll_AreOwnedPersistedAndRepeatable()
    {
        using var a = await Account();
        using var b = await Account();
        using var anonymous = factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync("/api/notifications")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.PutAsJsonAsync("/api/notifications/read-all", new { })).StatusCode);
        var ids = Enumerable.Range(0, 3).Select(_ => Guid.NewGuid()).ToList();
        var otherId = Guid.NewGuid();
        await using (var scope = factory.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var at = DateTime.UtcNow.AddMinutes(-10);
            foreach (var id in ids)
                db.UserNotifications.Add(new UserNotification { Id = id, UserId = a.UserId, Kind = "water", Title = "Water", Body = "Reminder", ScheduledAtUtc = at, CreatedAt = at });
            db.UserNotifications.Add(new UserNotification { Id = otherId, UserId = b.UserId, Kind = "workout", Title = "Workout", Body = "Reminder", ScheduledAtUtc = at, CreatedAt = at });
            await db.SaveChangesAsync();
        }
        var first = await a.Client.GetFromJsonAsync<JsonElement>("/api/notifications?pageSize=2");
        var second = await a.Client.GetFromJsonAsync<JsonElement>("/api/notifications?page=2&pageSize=2");
        Assert.Equal(3, first.GetProperty("unreadCount").GetInt32());
        Assert.True(first.GetProperty("hasMore").GetBoolean());
        Assert.False(second.GetProperty("hasMore").GetBoolean());
        var listed = first.GetProperty("items").EnumerateArray().Concat(second.GetProperty("items").EnumerateArray())
            .Select(item => item.GetProperty("id").GetGuid()).ToList();
        Assert.Equal(3, listed.Distinct().Count());
        Assert.All(ids, id => Assert.Contains(id, listed));
        Assert.Equal(HttpStatusCode.NotFound, (await a.Client.PutAsJsonAsync($"/api/notifications/{otherId}/read", new { })).StatusCode);
        foreach (var query in new[] { "page=0", "pageSize=101", "page=2147483647&pageSize=100" })
            Assert.Equal(HttpStatusCode.BadRequest, (await a.Client.GetAsync($"/api/notifications?{query}")).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await a.Client.PutAsJsonAsync($"/api/notifications/{ids[0]}/read", new { })).StatusCode);
        DateTime? readAt;
        await using (var scope = factory.Services.CreateAsyncScope())
            readAt = (await scope.ServiceProvider.GetRequiredService<ApplicationDbContext>().UserNotifications.SingleAsync(n => n.Id == ids[0])).ReadAt;
        foreach (var _ in new[] { 1, 2 })
            Assert.Equal(HttpStatusCode.NoContent, (await a.Client.PutAsJsonAsync("/api/notifications/read-all", new { })).StatusCode);
        await using (var scope = factory.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            Assert.Equal(readAt, (await db.UserNotifications.SingleAsync(n => n.Id == ids[0])).ReadAt);
            Assert.Null((await db.UserNotifications.SingleAsync(n => n.Id == otherId)).ReadAt);
        }
        var own = await a.Client.GetFromJsonAsync<JsonElement>("/api/notifications");
        var other = await b.Client.GetFromJsonAsync<JsonElement>("/api/notifications");
        Assert.Equal(0, own.GetProperty("unreadCount").GetInt32());
        Assert.Equal(1, other.GetProperty("unreadCount").GetInt32());
    }

    [Fact]
    public async Task ReminderSettings_RejectStaleRevision_AndNeverOverwriteAnotherAccount()
    {
        using var a = await Account();
        using var b = await Account();
        var request = new ReminderSettingsDto { WorkoutEnabled = true, WaterEnabled = true, TimeZone = "Asia/Bangkok" };
        var saved = await a.Client.PutAsJsonAsync("/api/notifications/settings", request);
        Assert.Equal(HttpStatusCode.OK, saved.StatusCode);
        var settings = (await saved.Content.ReadFromJsonAsync<ReminderSettingsDto>())!;
        Assert.Equal(1, settings.Revision);
        request.WaterEnabled = false;
        Assert.Equal(HttpStatusCode.Conflict, (await a.Client.PutAsJsonAsync("/api/notifications/settings", request)).StatusCode);
        var loadedA = (await a.Client.GetFromJsonAsync<ReminderSettingsDto>("/api/notifications/settings"))!;
        var loadedB = (await b.Client.GetFromJsonAsync<ReminderSettingsDto>("/api/notifications/settings"))!;
        Assert.True(loadedA.WaterEnabled);
        Assert.False(loadedB.WaterEnabled);
        Assert.Equal(0, loadedB.Revision);
        settings.WaterEnabled = false;
        settings.WorkoutEnabled = false;
        Assert.Equal(HttpStatusCode.OK, (await a.Client.PutAsJsonAsync("/api/notifications/settings", settings)).StatusCode);
        var disabled = (await a.Client.GetFromJsonAsync<ReminderSettingsDto>("/api/notifications/settings"))!;
        Assert.Equal(2, disabled.Revision);
        Assert.False(disabled.WaterEnabled);
        Assert.False(disabled.WorkoutEnabled);
        disabled.WaterStart = "22:00";
        disabled.WaterEnd = "09:00";
        Assert.Equal(HttpStatusCode.BadRequest, (await a.Client.PutAsJsonAsync("/api/notifications/settings", disabled)).StatusCode);
    }

    [Fact]
    public async Task FeedbackAcknowledgement_IsOwnedAndRejectsInvalidOrChangedRetries()
    {
        using var a = await Account();
        using var b = await Account();
        var id = Guid.NewGuid();
        var payload = new { requestId = id, subject = "Góp ý", content = "Phản hồi" };
        Assert.Equal(HttpStatusCode.Created, (await a.Client.PostAsJsonAsync("/api/support/feedback", payload)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await a.Client.PostAsJsonAsync("/api/support/feedback", payload)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await b.Client.PostAsJsonAsync("/api/support/feedback", payload)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await a.Client.PostAsJsonAsync("/api/support/feedback", new { requestId = id, content = "Different" })).StatusCode);
        foreach (var content in new string?[] { null, "  ", new('x', 4001) })
            Assert.Equal(HttpStatusCode.BadRequest, (await a.Client.PostAsJsonAsync("/api/support/feedback", new { requestId = Guid.NewGuid(), content })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await a.Client.PostAsJsonAsync("/api/support/feedback", new { requestId = Guid.Empty, content = "X" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await a.Client.PostAsJsonAsync("/api/support/feedback", new { requestId = Guid.NewGuid(), subject = new string('x', 121), content = "X" })).StatusCode);
        await using var scope = factory.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var row = Assert.Single(await db.UserFeedback.Where(f => f.Id == id).ToListAsync());
        Assert.Equal(a.UserId, row.UserId);
        Assert.Equal("Phản hồi", row.Content);
    }

    private async Task<TestAccount> Account()
    {
        var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/register", new { fullName = "API contract", email = $"{Guid.NewGuid():N}@example.com", password = "123123123Az!" });
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", json.GetProperty("token").GetString());
        return new TestAccount(client, json.GetProperty("userId").GetString()!);
    }

    private sealed record TestAccount(HttpClient Client, string UserId) : IDisposable
    {
        public void Dispose() => Client.Dispose();
    }
}
