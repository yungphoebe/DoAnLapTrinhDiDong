using System.Security.Claims;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class PostsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public PostsController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<PostResponse>>> GetPosts()
    {
        var posts = await Responses(_context.Posts.OrderByDescending(post => post.CreatedAt))
            .ToListAsync();

        return Ok(posts);
    }

    [HttpGet("feed")]
    public async Task<ActionResult<PostPageResponse>> GetFeed(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        if (page < 1 || pageSize < 1 || pageSize > 100 || (long)page * pageSize > int.MaxValue)
        {
            return BadRequest(new { message = "Invalid page or pageSize (1-100)." });
        }

        var query = _context.Posts
            .OrderByDescending(post => post.CreatedAt)
            .ThenByDescending(post => post.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize + 1);
        var posts = await Responses(query).ToListAsync(cancellationToken);

        return Ok(new PostPageResponse(posts.Take(pageSize).ToList(), page, pageSize, posts.Count > pageSize));
    }

    [HttpPost]
    public async Task<ActionResult<PostResponse>> CreatePost(CreatePostRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Content))
        {
            return BadRequest(new { message = "Content is required." });
        }

        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");
        var authorName = User.FindFirstValue("name")
            ?? User.FindFirstValue(ClaimTypes.Email)
            ?? User.FindFirstValue("email")
            ?? "User";

        var post = new Post
        {
            AuthorId = userId!,
            AuthorName = await ResolveAuthorNameAsync(userId!, authorName),
            Content = request.Content.Trim(),
            ImageAsset = string.IsNullOrWhiteSpace(request.ImageAsset) ? null : request.ImageAsset.Trim(),
            Tag = string.IsNullOrWhiteSpace(request.Tag) ? "Bai viet" : request.Tag.Trim(),
            CreatedAt = DateTime.UtcNow
        };

        _context.Posts.Add(post);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetPosts), new { id = post.Id }, await Responses(_context.Posts.Where(p => p.Id == post.Id)).SingleAsync());
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<PostResponse>> UpdatePost(int id, UpdatePostRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Content) || request.Content.Trim().Length > 1000)
        {
            return BadRequest(new { message = "Nội dung bài viết phải có từ 1 đến 1000 ký tự." });
        }

        var post = await _context.Posts.FindAsync(id);
        if (post is null)
        {
            return NotFound();
        }

        if (!CanMutate(post))
        {
            return Forbid();
        }

        post.Content = request.Content.Trim();
        await _context.SaveChangesAsync();
        return Ok(await Responses(_context.Posts.Where(p => p.Id == post.Id)).SingleAsync());
    }

    [HttpPut("{id:int}/like")]
    public async Task<ActionResult<PostLikeResponse>> SetLike(int id, SetPostLikeRequest request)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");
        if (string.IsNullOrEmpty(userId)) return Unauthorized();
        if (!await _context.Posts.AnyAsync(post => post.Id == id)) return NotFound();

        if (_context.Database.IsSqlServer())
        {
            if (request.Liked == true)
            {
                // The range lock and composite primary key prevent duplicate likes
                // even when identical requests reach different API instances.
                await _context.Database.ExecuteSqlInterpolatedAsync($"""
                    INSERT INTO dbo.PostLikes (PostId, UserId)
                    SELECT {id}, {userId}
                    WHERE NOT EXISTS (
                        SELECT 1 FROM dbo.PostLikes WITH (UPDLOCK, HOLDLOCK)
                        WHERE PostId = {id} AND UserId = {userId}
                    )
                    """);
            }
            else
            {
                await _context.Database.ExecuteSqlInterpolatedAsync(
                    $"DELETE FROM dbo.PostLikes WHERE PostId = {id} AND UserId = {userId}");
            }
        }
        else
        {
            var existing = await _context.PostLikes.FindAsync(id, userId);
            if (request.Liked == true && existing is null)
                _context.PostLikes.Add(new PostLike { PostId = id, UserId = userId });
            else if (request.Liked == false && existing is not null)
                _context.PostLikes.Remove(existing);
            await _context.SaveChangesAsync();
        }

        var result = await Responses(_context.Posts.Where(post => post.Id == id)).SingleOrDefaultAsync();
        return result is null ? NotFound() : Ok(new PostLikeResponse(id, result.Liked, result.LikeCount));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeletePost(int id)
    {
        var post = await _context.Posts.FindAsync(id);
        if (post is null)
        {
            return NotFound();
        }

        if (!CanMutate(post))
        {
            return Forbid();
        }

        _context.Posts.Remove(post);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    private bool CanMutate(Post post)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");
        return User.IsInRole("Admin") || post.AuthorId == userId;
    }

    private async Task<string> ResolveAuthorNameAsync(string userId, string fallback)
    {
        var user = await _context.Users.FindAsync(userId);
        return string.IsNullOrWhiteSpace(user?.FullName) ? fallback : user.FullName;
    }

    private IQueryable<PostResponse> Responses(IQueryable<Post> posts)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");
        return posts.AsNoTracking().Select(post => new PostResponse(
            post.Id, post.AuthorId, post.AuthorName, post.Content, post.ImageAsset, post.Tag,
            post.Likes.Count, post.Likes.Any(like => like.UserId == userId), post.CreatedAt,
            post.Comments.Count));
    }
}
