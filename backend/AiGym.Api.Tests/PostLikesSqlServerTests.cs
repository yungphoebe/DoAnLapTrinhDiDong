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

public sealed class SqlServerFactAttribute : FactAttribute
{
    public SqlServerFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("AIGYM_TEST_SQLSERVER")))
            Skip = "Set AIGYM_TEST_SQLSERVER to run against an isolated SQL Server test database.";
    }
}

public sealed class PostLikesSqlServerTests
{
    [SqlServerFact]
    public async Task SqlServer_UpgradesExistingSchema_HandlesConcurrentLikes_AndPersistsPerAccount()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("AIGYM_TEST_SQLSERVER"))
        {
            InitialCatalog = $"AiGymLikesTest_{Guid.NewGuid():N}"
        };
        var options = new DbContextOptionsBuilder<ApplicationDbContext>().UseSqlServer(connection.ConnectionString).Options;
        await using var setup = new ApplicationDbContext(options);
        try
        {
            await setup.Database.EnsureCreatedAsync();
            // This database belongs only to this test. Simulate the pre-likes schema.
            await setup.Database.ExecuteSqlRawAsync("DROP TABLE dbo.PostLikes");
            await PostLikesSchema.EnsureAsync(setup);
            await PostLikesSchema.EnsureAsync(setup);
            setup.Users.AddRange(
                new ApplicationUser { Id = "a", UserName = "a", FullName = "Account A" },
                new ApplicationUser { Id = "b", UserName = "b", FullName = "Account B" });
            var post = new Post { AuthorId = "a", AuthorName = "Account A", Content = "SQL persistence", LikeCount = 128 };
            setup.Posts.Add(post);
            await setup.SaveChangesAsync();

            async Task<PostLikeResponse> SetLike(string userId, bool liked)
            {
                await using var context = new ApplicationDbContext(options);
                var result = await Controller(context, userId).SetLike(post.Id, new SetPostLikeRequest(liked));
                return Assert.IsType<PostLikeResponse>(Assert.IsType<OkObjectResult>(result.Result).Value);
            }

            var results = await Task.WhenAll(Enumerable.Range(0, 12).Select(_ => SetLike("a", true)));
            Assert.All(results, result => { Assert.True(result.Liked); Assert.Equal(1, result.LikeCount); });
            Assert.Equal(2, (await SetLike("b", true)).LikeCount);
            Assert.Equal(1, (await SetLike("a", false)).LikeCount);
            var removed = await Task.WhenAll(Enumerable.Range(0, 12).Select(_ => SetLike("a", false)));
            Assert.All(removed, result => { Assert.False(result.Liked); Assert.Equal(1, result.LikeCount); });

            // Dispose all request contexts and read again, as after reopening the app.
            await using var reopened = new ApplicationDbContext(options);
            foreach (var (userId, liked) in new[] { ("a", false), ("b", true) })
            {
                var result = await Controller(reopened, userId).GetFeed();
                var feed = Assert.IsType<PostPageResponse>(Assert.IsType<OkObjectResult>(result.Result).Value);
                Assert.Equal(liked, feed.Items.Single().Liked);
                Assert.Equal(1, feed.Items.Single().LikeCount);
            }
            Assert.Equal(0, (await SetLike("b", false)).LikeCount);
            Assert.Equal(0, (await SetLike("b", false)).LikeCount);
            Assert.Equal(0, await reopened.PostLikes.CountAsync());
        }
        finally
        {
            // Only the randomly named database created above is removed.
            await setup.Database.EnsureDeletedAsync();
        }
    }

    private static PostsController Controller(ApplicationDbContext context, string userId) => new(context)
    {
        ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(new[] { new Claim(ClaimTypes.NameIdentifier, userId) }, "Test"))
            }
        }
    };
}
