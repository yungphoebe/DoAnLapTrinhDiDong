using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AiGym.Api.Services;
using AiGym.Api.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

namespace AiGym.Api.Tests;

public sealed class AuthAndPostsApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;

    public AuthAndPostsApiTests(ApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Register_ReturnsJwtWithUserRole_AndMeProfile()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/api/auth/register",
            new
            {
                fullName = "Nguyen Van A",
                email = "user1@example.com",
                password = "123123123Az!"
            });

        response.EnsureSuccessStatusCode();
        var auth = await response.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.NotNull(auth);
        Assert.Equal("user1@example.com", auth.Email);
        Assert.Equal("User", auth.Role);
        Assert.False(string.IsNullOrWhiteSpace(auth.Token));

        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(auth.Token);
        Assert.Contains(jwt.Claims, claim => claim.Type == "role" && claim.Value == "User");
        Assert.Contains(jwt.Claims, claim => claim.Type == "email" && claim.Value == "user1@example.com");
        Assert.True(jwt.ValidTo > DateTime.UtcNow);

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.Token);
        var me = await client.GetFromJsonAsync<MeResponse>("/api/auth/me");

        Assert.NotNull(me);
        Assert.Equal(auth.UserId, me.UserId);
        Assert.Equal("Nguyen Van A", me.FullName);
        Assert.Equal("User", me.Role);
    }

    [Fact]
    public async Task Login_SeededAdmin_ReturnsAdminRole()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/api/auth/login",
            new
            {
                email = "admin123@gmail.com",
                password = "123123123Az!"
            });

        response.EnsureSuccessStatusCode();
        var auth = await response.Content.ReadFromJsonAsync<AuthResponse>();

        Assert.NotNull(auth);
        Assert.Equal("admin123@gmail.com", auth.Email);
        Assert.Equal("Admin", auth.Role);
        Assert.False(string.IsNullOrWhiteSpace(auth.Token));
    }

    [Fact]
    public async Task SwaggerUi_IsAvailableForManualApiTesting()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/swagger/index.html");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("Swagger UI", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task SwaggerUi_AutoAuthorizesBearerTokenAfterLogin()
    {
        var client = _factory.CreateClient();

        var swagger = await client.GetStringAsync("/swagger/index.html");
        var script = await client.GetStringAsync("/swagger/auto-auth.js");

        Assert.Contains("/swagger/auto-auth.js", swagger);
        Assert.Contains("/api/auth/login", script);
        Assert.Contains("body.token", script);
        Assert.Contains("authActions.authorize", script);
        Assert.Contains("value: token", script);
        Assert.DoesNotContain("Bearer ${token}", script);
    }

    [Fact]
    public async Task AdminPage_IsAvailableForPostManagement()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/admin");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var html = await response.Content.ReadAsStringAsync();
        Assert.Contains("AI GYM Admin", html);
        Assert.Contains("/api/auth/login", html);
        Assert.Contains("/api/posts", html);
        Assert.Contains("data-action=\"create-post\"", html);
        Assert.Contains("data-action=\"edit-post\"", html);
        Assert.Contains("data-action=\"delete-post\"", html);
    }

    [Fact]
    public async Task Posts_RequireToken_AndAllowOwnerOrAdminToMutate()
    {
        var client = _factory.CreateClient();

        var anonymousPosts = await client.GetAsync("/api/posts");
        Assert.Equal(HttpStatusCode.Unauthorized, anonymousPosts.StatusCode);

        var anonymousCreate = await client.PostAsJsonAsync("/api/posts", new { content = "No token" });
        Assert.Equal(HttpStatusCode.Unauthorized, anonymousCreate.StatusCode);

        var owner = await RegisterAsync(client, "owner@example.com", "Owner");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", owner.Token);

        var posts = await client.GetFromJsonAsync<List<PostResponse>>("/api/posts");
        Assert.NotNull(posts);
        Assert.True(posts.Count >= 2);

        var create = await client.PostAsJsonAsync("/api/posts", new { content = "Tap nguc voi AI Gym" });
        create.EnsureSuccessStatusCode();
        var created = await create.Content.ReadFromJsonAsync<PostResponse>();
        Assert.NotNull(created);
        Assert.Equal("Tap nguc voi AI Gym", created.Content);
        Assert.Equal("Owner", created.AuthorName);

        client.DefaultRequestHeaders.Authorization = null;
        var anonymousUpdate = await client.PutAsJsonAsync($"/api/posts/{created.Id}", new { content = "Hack update" });
        Assert.Equal(HttpStatusCode.Unauthorized, anonymousUpdate.StatusCode);

        var anonymousDelete = await client.DeleteAsync($"/api/posts/{created.Id}");
        Assert.Equal(HttpStatusCode.Unauthorized, anonymousDelete.StatusCode);

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", owner.Token);
        var update = await client.PutAsJsonAsync($"/api/posts/{created.Id}", new { content = "Da sua noi dung" });
        update.EnsureSuccessStatusCode();
        var updated = await update.Content.ReadFromJsonAsync<PostResponse>();
        Assert.Equal("Da sua noi dung", updated!.Content);

        var other = await RegisterAsync(client, "other@example.com", "Other");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", other.Token);
        var forbiddenDelete = await client.DeleteAsync($"/api/posts/{created.Id}");
        Assert.Equal(HttpStatusCode.Forbidden, forbiddenDelete.StatusCode);

        var admin = await LoginAsync(client, "admin123@gmail.com", "123123123Az!");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", admin.Token);
        var adminDelete = await client.DeleteAsync($"/api/posts/{created.Id}");
        Assert.Equal(HttpStatusCode.NoContent, adminDelete.StatusCode);
    }

    [Fact]
    public async Task ForgotPassword_SendsResetToken_AndResetPasswordAllowsLogin()
    {
        var client = _factory.CreateClient();
        var email = $"reset-{Guid.NewGuid():N}@example.com";
        await RegisterAsync(client, email, "Reset User");

        var resetBaseUrl = "https://app.example.com/#/reset-password";
        var forgot = await client.PostAsJsonAsync("/api/auth/forgot-password", new { email, resetBaseUrl });

        forgot.EnsureSuccessStatusCode();
        var message = await forgot.Content.ReadAsStringAsync();
        Assert.Contains("huong dan dat lai mat khau", message);
        Assert.Single(_factory.EmailSender.Messages);

        var sent = _factory.EmailSender.Messages.Single();
        Assert.Equal(email, sent.To);
        Assert.Contains("Reset token:", sent.Body);
        Assert.Contains("Link:", sent.Body);
        Assert.Contains($"https://app.example.com/#/reset-password?email={Uri.EscapeDataString(email)}&token=", sent.Body);
        var token = ExtractResetToken(sent.Body);

        var reset = await client.PostAsJsonAsync(
            "/api/auth/reset-password",
            new
            {
                email,
                token,
                newPassword = "New123123Az!"
            });

        reset.EnsureSuccessStatusCode();
        var login = await LoginAsync(client, email, "New123123Az!");
        Assert.Equal(email, login.Email);
        Assert.False(string.IsNullOrWhiteSpace(login.Token));
    }

    [Fact]
    public async Task ForgotPassword_UnknownEmail_ReturnsOkWithoutSendingEmail()
    {
        var client = _factory.CreateClient();

        var forgot = await client.PostAsJsonAsync(
            "/api/auth/forgot-password",
            new { email = $"missing-{Guid.NewGuid():N}@example.com" });

        forgot.EnsureSuccessStatusCode();
        Assert.Empty(_factory.EmailSender.Messages);
    }

    [Fact]
    public async Task Feed_PaginatesDatabasePosts_AndPreservesFields()
    {
        var client = _factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/posts/feed")).StatusCode);
        var auth = await RegisterAsync(client, $"feed-{Guid.NewGuid():N}@example.com", "Feed Author");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.Token);
        var createdIds = new List<int>();
        for (var i = 0; i < 3; i++)
        {
            var response = await client.PostAsJsonAsync("/api/posts", new
            {
                content = $"Nội dung {i}", imageAsset = "https://example.com/post.jpg", tag = "Gym"
            });
            response.EnsureSuccessStatusCode();
            createdIds.Add((await response.Content.ReadFromJsonAsync<PostResponse>())!.Id);
        }

        var first = await client.GetFromJsonAsync<JsonElement>("/api/posts/feed?page=1&pageSize=2");
        var items = first.GetProperty("items");
        Assert.Equal(2, items.GetArrayLength());
        Assert.True(first.GetProperty("hasMore").GetBoolean());
        Assert.Equal(createdIds[2], items[0].GetProperty("id").GetInt32());
        Assert.Equal("Feed Author", items[0].GetProperty("authorName").GetString());
        Assert.Equal("Nội dung 2", items[0].GetProperty("content").GetString());
        Assert.Equal("https://example.com/post.jpg", items[0].GetProperty("imageAsset").GetString());
        var second = await client.GetFromJsonAsync<JsonElement>("/api/posts/feed?page=2&pageSize=2");
        Assert.Equal(createdIds[0], second.GetProperty("items")[0].GetProperty("id").GetInt32());
        var empty = await client.GetFromJsonAsync<JsonElement>("/api/posts/feed?page=10000&pageSize=2");
        Assert.Equal(0, empty.GetProperty("items").GetArrayLength());
        Assert.False(empty.GetProperty("hasMore").GetBoolean());
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/api/posts/feed?page=0")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/api/posts/feed?pageSize=101")).StatusCode);
    }

    [Fact]
    public async Task Likes_AreIdempotent_PerAccount_AndSurviveNewSessions()
    {
        using var first = _factory.CreateClient();
        using var second = _factory.CreateClient();
        var firstEmail = $"like-a-{Guid.NewGuid():N}@example.com";
        var secondEmail = $"like-b-{Guid.NewGuid():N}@example.com";
        var a = await RegisterAsync(first, firstEmail, "Like A");
        var b = await RegisterAsync(second, secondEmail, "Like B");
        first.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", a.Token);
        second.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", b.Token);
        var created = await first.PostAsJsonAsync("/api/posts", new { content = "Persistent likes" });
        var post = (await created.Content.ReadFromJsonAsync<PostResponse>())!;
        var path = $"/api/posts/{post.Id}/like";

        async Task AssertLike(HttpClient client, bool liked, int count)
        {
            var response = await client.PutAsJsonAsync(path, new { liked });
            response.EnsureSuccessStatusCode();
            var result = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(liked, result.GetProperty("liked").GetBoolean());
            Assert.Equal(count, result.GetProperty("likeCount").GetInt32());
        }

        await AssertLike(first, true, 1);
        await AssertLike(first, true, 1);
        var bFeed = (await second.GetFromJsonAsync<List<PostResponse>>("/api/posts"))!.Single(p => p.Id == post.Id);
        Assert.False(bFeed.Liked);
        Assert.Equal(1, bFeed.LikeCount);
        await AssertLike(second, true, 2);
        await AssertLike(first, false, 1);
        await AssertLike(first, false, 1);

        // New clients and new JWTs simulate closing and reopening the app.
        using var reopenedA = _factory.CreateClient();
        using var reopenedB = _factory.CreateClient();
        var newA = await LoginAsync(reopenedA, firstEmail, "123123123Az!");
        var newB = await LoginAsync(reopenedB, secondEmail, "123123123Az!");
        reopenedA.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", newA.Token);
        reopenedB.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", newB.Token);
        foreach (var (client, expectedLiked) in new[] { (reopenedA, false), (reopenedB, true) })
        {
            var feed = await client.GetFromJsonAsync<JsonElement>("/api/posts/feed?pageSize=100");
            var saved = feed.GetProperty("items").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == post.Id);
            Assert.Equal(expectedLiked, saved.GetProperty("liked").GetBoolean());
            Assert.Equal(1, saved.GetProperty("likeCount").GetInt32());
        }
        await AssertLike(reopenedB, false, 0);
        await AssertLike(reopenedB, false, 0);
    }

    [Fact]
    public async Task Likes_ValidateAuthPostAndExplicitState()
    {
        using var client = _factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PutAsJsonAsync("/api/posts/1/like", new { liked = true })).StatusCode);
        var auth = await LoginAsync(client, DatabaseSeeder.AdminEmail, DatabaseSeeder.AdminPassword);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.Token);
        Assert.Equal(HttpStatusCode.NotFound, (await client.PutAsJsonAsync("/api/posts/2147483647/like", new { liked = true })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PutAsJsonAsync("/api/posts/1/like", new { })).StatusCode);
    }

    private static async Task<AuthResponse> RegisterAsync(HttpClient client, string email, string fullName)
    {
        var response = await client.PostAsJsonAsync(
            "/api/auth/register",
            new { fullName, email, password = "123123123Az!" });
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
    }

    private static async Task<AuthResponse> LoginAsync(HttpClient client, string email, string password)
    {
        var response = await client.PostAsJsonAsync("/api/auth/login", new { email, password });
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
    }

    private static string ExtractResetToken(string body)
    {
        const string marker = "Reset token:";
        var start = body.IndexOf(marker, StringComparison.Ordinal);
        Assert.True(start >= 0);
        return body[(start + marker.Length)..].Trim().Split('\n', '\r')[0].Trim();
    }

    private sealed record AuthResponse(
        string Token,
        string UserId,
        string Email,
        string FullName,
        string Role,
        DateTime ExpiresAt);

    private sealed record MeResponse(string UserId, string Email, string FullName, string Role, DateTime ExpiresAt);

    private sealed record PostResponse(
        int Id,
        string AuthorId,
        string AuthorName,
        string Content,
        string? ImageAsset,
        string Tag,
        int LikeCount,
        bool Liked,
        DateTime CreatedAt);
}

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    private readonly string _databaseName = $"aigym-tests-{Guid.NewGuid():N}";
    public FakeEmailSender EmailSender { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("Testing:DatabaseName", _databaseName);
        builder.ConfigureTestServices(services =>
        {
            services.AddDbContext<ApplicationDbContext>(options => options.UseInMemoryDatabase(_databaseName));
            services.AddSingleton<IEmailSender>(EmailSender);
            services.Configure<AiGym.Api.Options.LmStudioOptions>(options => options.BaseUrl = "http://localhost:1234");
        });
    }

    protected override void ConfigureClient(HttpClient client)
    {
        EmailSender.Clear();
        base.ConfigureClient(client);
    }
}

public sealed class FakeEmailSender : IEmailSender
{
    private readonly List<EmailMessage> _messages = [];

    public IReadOnlyList<EmailMessage> Messages => _messages;

    public Task SendAsync(string to, string subject, string body)
    {
        _messages.Add(new EmailMessage(to, subject, body));
        return Task.CompletedTask;
    }

    public void Clear() => _messages.Clear();
}

public sealed record EmailMessage(string To, string Subject, string Body);
