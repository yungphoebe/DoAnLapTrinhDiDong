using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AiGym.Api.Services;
using AiGym.Api.Data;
using AiGym.Api.Models;
using AiGym.Api.Dtos;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using WebPush;

namespace AiGym.Api.Tests;

public sealed class NotificationsApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public NotificationsApiTests(ApiFactory factory) => _factory = factory;

    [Fact]
    public async Task SettingsRequireAuth_PersistAndValidate_AndInboxStartsEmpty()
    {
        using var client = _factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/notifications/settings")).StatusCode);
        var login = await client.PostAsJsonAsync("/api/auth/login", new { email = DatabaseSeeder.AdminEmail, password = DatabaseSeeder.AdminPassword });
        var auth = await login.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.GetProperty("token").GetString());
        var settings = await client.GetAsync("/api/notifications/settings");
        settings.EnsureSuccessStatusCode();
        var initial = await settings.Content.ReadFromJsonAsync<JsonElement>();
        Assert.False(initial.GetProperty("workoutEnabled").GetBoolean());
        var saved = await client.PutAsJsonAsync("/api/notifications/settings", new {
            workoutEnabled = true, workoutTime = "18:00", workoutDays = new[] {1, 3, 5},
            waterEnabled = true, waterStart = "09:00", waterEnd = "21:00", waterIntervalMinutes = 120,
            weeklyEnabled = true, weeklyDay = 7, weeklyTime = "20:00", timeZone = "Asia/Bangkok"
        });
        saved.EnsureSuccessStatusCode();
        var loaded = await client.GetFromJsonAsync<JsonElement>("/api/notifications/settings");
        Assert.True(loaded.GetProperty("waterEnabled").GetBoolean());
        Assert.Equal("18:00", loaded.GetProperty("workoutTime").GetString());
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PutAsJsonAsync("/api/notifications/settings", new { timeZone = "invalid" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/api/notifications?page=0")).StatusCode);
        var inbox = await client.GetFromJsonAsync<JsonElement>("/api/notifications");
        Assert.True(inbox.TryGetProperty("unreadCount", out _));
        Assert.Equal(HttpStatusCode.NotFound, (await client.PutAsJsonAsync($"/api/notifications/{Guid.NewGuid()}/read", new {})).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/notifications/subscriptions", new {
            endpoint = "http://127.0.0.1/private", p256dh = "x", auth = "x", sessionId = "device"
        })).StatusCode);
    }

    [Fact]
    public async Task InboxAndSubscriptionsAreOwned_AndReadIsIdempotent()
    {
        using var a=_factory.CreateClient();using var b=_factory.CreateClient();
        async Task<JsonElement> Register(HttpClient client,string name){
            var response=await client.PostAsJsonAsync("/api/auth/register",new{fullName=name,email=$"notice-{Guid.NewGuid():N}@example.com",password="123123123Az!"});
            response.EnsureSuccessStatusCode();var auth=await response.Content.ReadFromJsonAsync<JsonElement>();
            client.DefaultRequestHeaders.Authorization=new AuthenticationHeaderValue("Bearer",auth.GetProperty("token").GetString());return auth;
        }
        var user=await Register(a,"A");await Register(b,"B");var id=Guid.NewGuid();
        using(var scope=_factory.Services.CreateScope()){
            var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.UserNotifications.Add(new UserNotification{Id=id,UserId=user.GetProperty("userId").GetString()!,Kind="water",Title="Water",Body="Reminder",ScheduledAtUtc=DateTime.UtcNow,CreatedAt=DateTime.UtcNow});
            await db.SaveChangesAsync();
        }
        Assert.Equal(HttpStatusCode.NotFound,(await b.PutAsJsonAsync($"/api/notifications/{id}/read",new{})).StatusCode);
        var otherInbox=await b.GetFromJsonAsync<JsonElement>("/api/notifications");Assert.Equal(0,otherInbox.GetProperty("items").GetArrayLength());
        foreach(var _ in new[]{1,2})Assert.Equal(HttpStatusCode.NoContent,(await a.PutAsJsonAsync($"/api/notifications/{id}/read",new{})).StatusCode);
        var ownInbox=await a.GetFromJsonAsync<JsonElement>("/api/notifications");Assert.Equal(0,ownInbox.GetProperty("unreadCount").GetInt32());
        var endpoint=$"https://fcm.googleapis.com/fcm/send/{Guid.NewGuid():N}";
        var key=VapidHelper.GenerateVapidKeys().PublicKey;
        var authKey=Convert.ToBase64String(new byte[16]).TrimEnd('=').Replace('+','-').Replace('/','_');
        var subscription=new PushSubscriptionRequest(endpoint,key,authKey,"session-a");
        Assert.True(NotificationPush.ValidSubscription(subscription));
        Assert.False(NotificationPush.ValidSubscription(subscription with{P256dh=Convert.ToBase64String(new byte[65])}));
        Assert.Equal(HttpStatusCode.NoContent,(await a.PostAsJsonAsync("/api/notifications/subscriptions",subscription)).StatusCode);
        using var delete=new HttpRequestMessage(HttpMethod.Delete,"/api/notifications/subscriptions"){Content=JsonContent.Create(new{endpoint})};
        Assert.Equal(HttpStatusCode.NoContent,(await b.SendAsync(delete)).StatusCode);
        using(var scope=_factory.Services.CreateScope())Assert.True(await scope.ServiceProvider.GetRequiredService<ApplicationDbContext>().BrowserPushSubscriptions.AnyAsync(s=>s.Endpoint==endpoint && s.UserId==user.GetProperty("userId").GetString()));
    }
}
