using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AiGym.Api.Data;
using AiGym.Api.Models;
using AiGym.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace AiGym.Api.Tests;

public sealed class FeedCommentsApiTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task Comments_PersistWithRealAuthor_AndRetryDoesNotDuplicate()
    {
        using var author = await Account("Comment author");
        using var reader = await Account("Reader");
        var postId = await SeedPost(author.UserId);
        var id = Guid.NewGuid();
        var payload = new { requestId = id, content = "  Bình luận thật  ", authorId = reader.UserId };
        var created = await author.Client.PostAsJsonAsync($"/api/posts/{postId}/comments", payload);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var saved = await created.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(id, saved.GetProperty("id").GetGuid());
        Assert.Equal(author.UserId, saved.GetProperty("authorId").GetString());
        Assert.Equal("Comment author", saved.GetProperty("authorName").GetString());
        Assert.Equal("Bình luận thật", saved.GetProperty("content").GetString());
        Assert.Equal(HttpStatusCode.OK, (await author.Client.PostAsJsonAsync($"/api/posts/{postId}/comments", payload)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await reader.Client.PostAsJsonAsync($"/api/posts/{postId}/comments", payload)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await author.Client.PostAsJsonAsync($"/api/posts/{postId}/comments", new { requestId = id, content = "Khác" })).StatusCode);
        var otherPostId = await SeedPost(author.UserId);
        Assert.Equal(HttpStatusCode.Conflict, (await author.Client.PostAsJsonAsync($"/api/posts/{otherPostId}/comments", payload)).StatusCode);

        // This GET is a fresh HTTP request/DbContext, as after reopening the app.
        var list = await reader.Client.GetFromJsonAsync<JsonElement>($"/api/posts/{postId}/comments");
        Assert.Equal(1, list.GetProperty("totalCount").GetInt32());
        Assert.Single(list.GetProperty("items").EnumerateArray());
        Assert.Equal(id, list.GetProperty("items")[0].GetProperty("id").GetGuid());
        var feed = await reader.Client.GetFromJsonAsync<JsonElement>("/api/posts/feed?pageSize=100");
        Assert.Equal(1, feed.GetProperty("items").EnumerateArray().Single(p => p.GetProperty("id").GetInt32() == postId).GetProperty("commentCount").GetInt32());
    }

    [Fact]
    public async Task CommentMutations_RequireTheCommentAuthorOrAdmin_AndCorrectPost()
    {
        using var postOwner = await Account("Post owner");
        using var commentOwner = await Account("Comment owner");
        using var outsider = await Account("Outsider");
        var postId = await SeedPost(postOwner.UserId);
        var wrongPost = await SeedPost(postOwner.UserId);
        var id = Guid.NewGuid();
        var path = $"/api/posts/{postId}/comments";
        Assert.Equal(HttpStatusCode.Created, (await commentOwner.Client.PostAsJsonAsync(path, new { requestId = id, content = "Original" })).StatusCode);
        foreach (var client in new[] { postOwner.Client, outsider.Client })
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PutAsJsonAsync($"{path}/{id}", new { content = "Hack" })).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.DeleteAsync($"{path}/{id}")).StatusCode);
        }
        Assert.Equal(HttpStatusCode.NotFound, (await commentOwner.Client.PutAsJsonAsync($"/api/posts/{wrongPost}/comments/{id}", new { content = "Wrong post" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await commentOwner.Client.DeleteAsync($"/api/posts/{wrongPost}/comments/{id}")).StatusCode);
        var update = await commentOwner.Client.PutAsJsonAsync($"{path}/{id}", new { content = " Edited " });
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);
        var edited = await update.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Edited", edited.GetProperty("content").GetString());
        Assert.NotEqual(JsonValueKind.Null, edited.GetProperty("updatedAt").ValueKind);
        Assert.Equal(HttpStatusCode.Conflict, (await commentOwner.Client.PostAsJsonAsync(path, new { requestId = id, content = "Original" })).StatusCode);

        using var admin = await Admin();
        Assert.Equal(HttpStatusCode.OK, (await admin.PutAsJsonAsync($"{path}/{id}", new { content = "Moderated" })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await admin.DeleteAsync($"{path}/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await commentOwner.Client.PutAsJsonAsync($"{path}/{id}", new { content = "Gone" })).StatusCode);
        var secondId = Guid.NewGuid();
        Assert.Equal(HttpStatusCode.Created, (await commentOwner.Client.PostAsJsonAsync(path, new { requestId = secondId, content = "Owner deletion" })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await commentOwner.Client.DeleteAsync($"{path}/{secondId}")).StatusCode);
        var list = await postOwner.Client.GetFromJsonAsync<JsonElement>(path);
        Assert.Equal(0, list.GetProperty("totalCount").GetInt32());
    }

    [Fact]
    public async Task Comments_RejectMissingAuthInvalidContentPaginationAndMissingPost()
    {
        using var owner = await Account("Validation");
        using var anonymous = factory.CreateClient();
        var postId = await SeedPost(owner.UserId);
        var path = $"/api/posts/{postId}/comments";
        var id = Guid.NewGuid();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync(path)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.PostAsJsonAsync(path, new { requestId = id, content = "X" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.PutAsJsonAsync($"{path}/{id}", new { content = "X" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.DeleteAsync($"{path}/{id}")).StatusCode);
        foreach (var query in new[] { "page=0", "pageSize=0", "pageSize=101", "page=2147483647&pageSize=100" })
            Assert.Equal(HttpStatusCode.BadRequest, (await owner.Client.GetAsync($"{path}?{query}")).StatusCode);
        foreach (var content in new string?[] { null, "   ", new('x', 1001) })
            Assert.Equal(HttpStatusCode.BadRequest, (await owner.Client.PostAsJsonAsync(path, new { requestId = id, content })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await owner.Client.PostAsJsonAsync(path, new { requestId = Guid.Empty, content = "X" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await owner.Client.GetAsync("/api/posts/2147483647/comments")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await owner.Client.PostAsJsonAsync("/api/posts/2147483647/comments", new { requestId = id, content = "X" })).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await owner.Client.PostAsJsonAsync(path, new { requestId = id, content = "X" })).StatusCode);
        foreach (var content in new string?[] { null, " ", new('x', 1001) })
            Assert.Equal(HttpStatusCode.BadRequest, (await owner.Client.PutAsJsonAsync($"{path}/{id}", new { content })).StatusCode);
        var saved = await owner.Client.GetFromJsonAsync<JsonElement>(path);
        Assert.Equal("X", saved.GetProperty("items")[0].GetProperty("content").GetString());
    }

    [Fact]
    public async Task Comments_PaginateWithoutDuplicates_AndFeedCountsOnlyThatPost()
    {
        using var owner = await Account("Pagination");
        var postId = await SeedPost(owner.UserId);
        var otherPost = await SeedPost(owner.UserId);
        for (var i = 0; i < 3; i++)
            Assert.Equal(HttpStatusCode.Created, (await owner.Client.PostAsJsonAsync($"/api/posts/{postId}/comments", new { requestId = Guid.NewGuid(), content = $"Comment {i}" })).StatusCode);
        var first = await owner.Client.GetFromJsonAsync<JsonElement>($"/api/posts/{postId}/comments?pageSize=2");
        var second = await owner.Client.GetFromJsonAsync<JsonElement>($"/api/posts/{postId}/comments?page=2&pageSize=2");
        Assert.Equal(3, first.GetProperty("totalCount").GetInt32());
        Assert.True(first.GetProperty("hasMore").GetBoolean());
        Assert.False(second.GetProperty("hasMore").GetBoolean());
        Assert.Equal(2, first.GetProperty("items").GetArrayLength());
        Assert.Single(second.GetProperty("items").EnumerateArray());
        var ids = first.GetProperty("items").EnumerateArray().Concat(second.GetProperty("items").EnumerateArray()).Select(c => c.GetProperty("id").GetGuid()).ToList();
        Assert.Equal(3, ids.Distinct().Count());
        var empty = await owner.Client.GetFromJsonAsync<JsonElement>($"/api/posts/{otherPost}/comments");
        Assert.Equal(0, empty.GetProperty("totalCount").GetInt32());
        var beyond = await owner.Client.GetFromJsonAsync<JsonElement>($"/api/posts/{postId}/comments?page=20");
        Assert.Empty(beyond.GetProperty("items").EnumerateArray());
    }

    [Fact]
    public async Task PostEdits_EnforceOwnershipAndTrimmedLength_WithoutChangingCreationFlow()
    {
        using var owner = await Account("Owner");
        using var other = await Account("Other");
        var postId = await SeedPost(owner.UserId);
        Assert.Equal(HttpStatusCode.Forbidden, (await other.Client.PutAsJsonAsync($"/api/posts/{postId}", new { content = "Hack" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await other.Client.DeleteAsync($"/api/posts/{postId}")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await owner.Client.PutAsJsonAsync($"/api/posts/{postId}", new { content = new string('x', 1001) })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await owner.Client.PutAsJsonAsync($"/api/posts/{postId}", new { content = "  " })).StatusCode);
        var update = await owner.Client.PutAsJsonAsync($"/api/posts/{postId}", new { content = "  Edited post  " });
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);
        Assert.Equal("Edited post", (await update.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("content").GetString());
        using var admin = await Admin();
        Assert.Equal(HttpStatusCode.OK, (await admin.PutAsJsonAsync($"/api/posts/{postId}", new { content = "Admin edit" })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await owner.Client.DeleteAsync($"/api/posts/{postId}")).StatusCode);
    }

    private async Task<int> SeedPost(string ownerId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var owner = await db.Users.SingleAsync(u => u.Id == ownerId);
        var post = new Post { AuthorId = ownerId, AuthorName = owner.FullName, Content = "Existing post" };
        db.Posts.Add(post);
        await db.SaveChangesAsync();
        return post.Id;
    }

    private async Task<TestAccount> Account(string name)
    {
        var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/register", new { fullName = name, email = $"{Guid.NewGuid():N}@example.com", password = "123123123Az!" });
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", json.GetProperty("token").GetString());
        return new TestAccount(client, json.GetProperty("userId").GetString()!);
    }

    private async Task<HttpClient> Admin()
    {
        var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/login", new { email = DatabaseSeeder.AdminEmail, password = DatabaseSeeder.AdminPassword });
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", json.GetProperty("token").GetString());
        return client;
    }

    private sealed record TestAccount(HttpClient Client, string UserId) : IDisposable
    {
        public void Dispose() => Client.Dispose();
    }
}
