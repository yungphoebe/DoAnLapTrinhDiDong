using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AiGym.Api.Services;
using AiGym.Api.Data;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Tests;

public sealed class SupportApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public SupportApiTests(ApiFactory factory) => _factory=factory;
    [Fact]
    public async Task ContentIsExplicitlyMissing_AndFeedbackRequiresAuthAndAcknowledgesSavedSubmission()
    {
        using var client=_factory.CreateClient();
        var content=await client.GetAsync("/api/support/content");
        content.EnsureSuccessStatusCode();
        var data=await content.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(JsonValueKind.Null,data.GetProperty("terms").ValueKind);
        Assert.Equal(HttpStatusCode.Unauthorized,(await client.PostAsJsonAsync("/api/support/feedback",new{content="test"})).StatusCode);
        var login=await client.PostAsJsonAsync("/api/auth/login",new{email=DatabaseSeeder.AdminEmail,password=DatabaseSeeder.AdminPassword});
        var auth=await login.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization=new AuthenticationHeaderValue("Bearer",auth.GetProperty("token").GetString());
        var id=Guid.NewGuid();
        var payload=new{requestId=id,subject="Góp ý",content="Nội dung cần phản hồi"};
        foreach(var _ in new[]{1,2})
        {
            var response=await client.PostAsJsonAsync("/api/support/feedback",payload);
            response.EnsureSuccessStatusCode();
            var saved=await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(id,saved.GetProperty("id").GetGuid());
        }
        using(var scope=_factory.Services.CreateScope())
        {
            var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var stored=await db.UserFeedback.SingleAsync(f=>f.Id==id);
            Assert.Equal("Nội dung cần phản hồi",stored.Content);
            Assert.Equal(auth.GetProperty("userId").GetString(),stored.UserId);
            Assert.Equal(1,await db.UserFeedback.CountAsync(f=>f.Id==id));
        }
        Assert.Equal(HttpStatusCode.BadRequest,(await client.PostAsJsonAsync("/api/support/feedback",new{requestId=Guid.NewGuid(),content="   "})).StatusCode);
    }
}
