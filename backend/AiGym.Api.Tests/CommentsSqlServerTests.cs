using System.Security.Claims;
using AiGym.Api.Controllers;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Tests;

public sealed class CommentsSqlServerTests
{
    [SqlServerFact]
    public async Task SqlServer_UpgradesTwice_PreservesData_AndEnforcesForeignKeysAndCascades()
    {
        var options = Options();
        await using var setup = new ApplicationDbContext(options);
        try
        {
            await setup.Database.EnsureCreatedAsync();
            setup.Users.AddRange(
                new ApplicationUser { Id = "a", UserName = "a", FullName = "Post author" },
                new ApplicationUser { Id = "b", UserName = "b", FullName = "Comment author" });
            var post = new Post { AuthorId = "a", AuthorName = "Post author", Content = "Preserve this post" };
            setup.Posts.Add(post);
            await setup.SaveChangesAsync();
            // Only this randomly named test database is changed; simulate an existing installation.
            await setup.Database.ExecuteSqlRawAsync("DROP TABLE dbo.PostComments");
            await CommentSchema.EnsureAsync(setup);
            await CommentSchema.EnsureAsync(setup);
            Assert.Equal("Preserve this post", (await setup.Posts.SingleAsync()).Content);

            var id = Guid.NewGuid();
            var created = await Comments(setup, "b").CreateComment(post.Id, new(id, "  Saved comment  "));
            Assert.IsType<CreatedAtActionResult>(created.Result);
            await using (var reopened = new ApplicationDbContext(options))
            {
                var list = await Comments(reopened, "a").GetComments(post.Id);
                var page = Assert.IsType<CommentPageResponse>(Assert.IsType<OkObjectResult>(list.Result).Value);
                Assert.Equal(1, page.TotalCount);
                Assert.Equal("Comment author", page.Items.Single().AuthorName);
                Assert.Equal("Saved comment", page.Items.Single().Content);
                Assert.Equal(id, page.Items.Single().Id);
                Assert.Equal(DateTimeKind.Utc, page.Items.Single().CreatedAt.Kind);
                var feed = await Posts(reopened, "a").GetFeed();
                Assert.Equal(1, Assert.IsType<PostPageResponse>(Assert.IsType<OkObjectResult>(feed.Result).Value).Items.Single().CommentCount);
            }

            // Check both FKs with direct writes, independently of HTTP validation.
            setup.PostComments.Add(new PostComment { Id = Guid.NewGuid(), PostId = int.MaxValue, AuthorId = "b", Content = "Invalid post" });
            await Assert.ThrowsAsync<DbUpdateException>(() => setup.SaveChangesAsync());
            setup.ChangeTracker.Clear();
            setup.PostComments.Add(new PostComment { Id = Guid.NewGuid(), PostId = post.Id, AuthorId = "missing", Content = "Invalid author" });
            await Assert.ThrowsAsync<DbUpdateException>(() => setup.SaveChangesAsync());
            setup.ChangeTracker.Clear();
            setup.PostLikes.Add(new PostLike { PostId = post.Id, UserId = "b" });
            await setup.SaveChangesAsync();

            // A fresh context has not loaded comments/likes: SQL Server must cascade itself.
            await using (var deleting = new ApplicationDbContext(options))
                Assert.IsType<NoContentResult>(await Posts(deleting, "a").DeletePost(post.Id));
            await using var final = new ApplicationDbContext(options);
            Assert.Equal(0, await final.PostComments.CountAsync());
            Assert.Equal(0, await final.PostLikes.CountAsync());
            Assert.Equal(2, await final.Users.CountAsync());
        }
        finally
        {
            await setup.Database.EnsureDeletedAsync();
        }
    }

    [SqlServerFact]
    public async Task SqlServer_ConcurrentRetriesInsertOnce_AndEditedCommentRejectsCreationReplay()
    {
        var options = Options();
        await using var setup = new ApplicationDbContext(options);
        try
        {
            await setup.Database.EnsureCreatedAsync();
            setup.Users.Add(new ApplicationUser { Id = "a", UserName = "a", FullName = "A" });
            var post = new Post { AuthorId = "a", AuthorName = "A", Content = "Existing post" };
            setup.Posts.Add(post);
            await setup.SaveChangesAsync();
            var id = Guid.NewGuid();
            var results = await Task.WhenAll(Enumerable.Range(0, 12).Select(async _ =>
            {
                await using var db = new ApplicationDbContext(options);
                return await Comments(db, "a").CreateComment(post.Id, new(id, "Same request"));
            }));
            Assert.Single(results, result => result.Result is CreatedAtActionResult);
            Assert.Equal(11, results.Count(result => result.Result is OkObjectResult));
            await using (var reopened = new ApplicationDbContext(options))
            {
                Assert.Equal(1, await reopened.PostComments.CountAsync());
                Assert.Equal("Same request", (await reopened.PostComments.SingleAsync()).Content);
                var edited = await Comments(reopened, "a").UpdateComment(post.Id, id, new("Updated"));
                Assert.IsType<OkObjectResult>(edited.Result);
            }
            await using (var retry = new ApplicationDbContext(options))
            {
                var result = await Comments(retry, "a").CreateComment(post.Id, new(id, "Same request"));
                Assert.IsType<ConflictObjectResult>(result.Result);
                Assert.Equal("Updated", (await retry.PostComments.SingleAsync()).Content);
                var page = Assert.IsType<CommentPageResponse>(Assert.IsType<OkObjectResult>((await Comments(retry, "a").GetComments(post.Id)).Result).Value);
                Assert.Equal(DateTimeKind.Utc, page.Items.Single().UpdatedAt!.Value.Kind);
            }

            // A tie in CreatedAt still has a deterministic second ordering key.
            setup.ChangeTracker.Clear();
            var timestamp = DateTime.UtcNow;
            setup.PostComments.AddRange(Enumerable.Range(0, 4).Select(index => new PostComment
            {
                Id = Guid.NewGuid(), PostId = post.Id, AuthorId = "a", Content = $"Tied {index}", CreatedAt = timestamp
            }));
            await setup.SaveChangesAsync();
            var controller = Comments(setup, "a");
            var first = Assert.IsType<CommentPageResponse>(Assert.IsType<OkObjectResult>((await controller.GetComments(post.Id, 1, 2)).Result).Value);
            var second = Assert.IsType<CommentPageResponse>(Assert.IsType<OkObjectResult>((await controller.GetComments(post.Id, 2, 2)).Result).Value);
            Assert.Equal(5, first.TotalCount);
            Assert.True(first.HasMore);
            Assert.Equal(4, first.Items.Concat(second.Items).Select(comment => comment.Id).Distinct().Count());
            Assert.All(first.Items.Concat(second.Items), comment => Assert.StartsWith("Tied ", comment.Content));
        }
        finally
        {
            await setup.Database.EnsureDeletedAsync();
        }
    }

    private static DbContextOptions<ApplicationDbContext> Options()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("AIGYM_TEST_SQLSERVER"))
        {
            InitialCatalog = $"AiGymCommentsTest_{Guid.NewGuid():N}"
        };
        return new DbContextOptionsBuilder<ApplicationDbContext>().UseSqlServer(connection.ConnectionString).Options;
    }

    private static ControllerContext Identity(string userId) => new()
    {
        HttpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, userId)], "Test"))
        }
    };

    private static PostCommentsController Comments(ApplicationDbContext db, string userId) => new(db) { ControllerContext = Identity(userId) };
    private static PostsController Posts(ApplicationDbContext db, string userId) => new(db) { ControllerContext = Identity(userId) };
}
