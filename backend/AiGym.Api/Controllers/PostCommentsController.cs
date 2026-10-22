using System.Security.Claims;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/posts/{postId:int}/comments")]
public sealed class PostCommentsController(ApplicationDbContext context) : ControllerBase
{
    private string? UserId => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");

    [HttpGet]
    public async Task<ActionResult<CommentPageResponse>> GetComments(
        int postId, [FromQuery] int page = 1, [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        if (page < 1 || pageSize < 1 || pageSize > 100 || (long)page * pageSize > int.MaxValue)
            return BadRequest(new { message = "Invalid page or pageSize (1-100)." });
        if (!await context.Posts.AnyAsync(post => post.Id == postId, cancellationToken))
            return NotFound();

        var comments = context.PostComments.AsNoTracking().Where(comment => comment.PostId == postId);
        var total = await comments.CountAsync(cancellationToken);
        var items = await Responses(comments.OrderByDescending(comment => comment.CreatedAt)
                .ThenByDescending(comment => comment.Id).Skip((page - 1) * pageSize).Take(pageSize + 1))
            .ToListAsync(cancellationToken);
        return Ok(new CommentPageResponse(items.Take(pageSize).ToList(), page, pageSize, items.Count > pageSize, total));
    }

    [HttpPost]
    public async Task<ActionResult<CommentResponse>> CreateComment(
        int postId, CreateCommentRequest request, CancellationToken cancellationToken = default)
    {
        if (request.RequestId == Guid.Empty || !ValidContent(request.Content))
            return InvalidContent();
        var userId = UserId;
        if (string.IsNullOrEmpty(userId) || !await context.Users.AnyAsync(user => user.Id == userId, cancellationToken))
            return Unauthorized();
        if (!await context.Posts.AnyAsync(post => post.Id == postId, cancellationToken))
            return NotFound();

        var content = request.Content!.Trim();
        var now = DateTime.UtcNow;
        bool created;
        if (context.Database.IsSqlServer())
        {
            try
            {
                // Single autocommit statement: range-lock the idempotency key across API instances.
                var inserted = await context.Database.ExecuteSqlInterpolatedAsync($"""
                    INSERT INTO dbo.PostComments (Id, PostId, AuthorId, Content, CreatedAt, UpdatedAt)
                    SELECT {request.RequestId}, {postId}, {userId}, {content}, {now}, NULL
                    WHERE NOT EXISTS (
                        SELECT 1 FROM dbo.PostComments WITH (UPDLOCK, HOLDLOCK)
                        WHERE Id = {request.RequestId}
                    )
                    """, cancellationToken);
                created = inserted > 0;
            }
            catch (SqlException error) when (error.Number == 547)
            {
                // The post or account can disappear after the existence checks.
                if (!await context.Users.AnyAsync(user => user.Id == userId, cancellationToken))
                    return Unauthorized();
                return NotFound();
            }
        }
        else
        {
            created = !await context.PostComments.AnyAsync(comment => comment.Id == request.RequestId, cancellationToken);
            if (created)
            {
                context.PostComments.Add(new PostComment
                {
                    Id = request.RequestId, PostId = postId, AuthorId = userId,
                    Content = content, CreatedAt = now
                });
                await context.SaveChangesAsync(cancellationToken);
            }
        }

        var saved = await Responses(context.PostComments.Where(comment => comment.Id == request.RequestId))
            .SingleOrDefaultAsync(cancellationToken);
        if (saved is null) return NotFound();
        if (saved.AuthorId != userId || saved.PostId != postId || saved.Content != content || saved.UpdatedAt is not null)
            return Conflict(new { message = "Mã gửi bình luận đã được sử dụng. Hãy tải lại bình luận." });

        return created
            ? CreatedAtAction(nameof(GetComments), new { postId }, saved)
            : Ok(saved);
    }

    [HttpPut("{commentId:guid}")]
    public async Task<ActionResult<CommentResponse>> UpdateComment(
        int postId, Guid commentId, UpdateCommentRequest request, CancellationToken cancellationToken = default)
    {
        if (!ValidContent(request.Content)) return InvalidContent();
        var comment = await context.PostComments.SingleOrDefaultAsync(
            item => item.Id == commentId && item.PostId == postId, cancellationToken);
        if (comment is null) return NotFound();
        if (!CanMutate(comment)) return Forbid();

        comment.Content = request.Content!.Trim();
        comment.UpdatedAt = DateTime.UtcNow;
        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // A concurrent delete must not be reported as a successful edit.
            return NotFound();
        }
        var saved = await Responses(context.PostComments.Where(item => item.Id == commentId))
            .SingleOrDefaultAsync(cancellationToken);
        return saved is null ? NotFound() : Ok(saved);
    }

    [HttpDelete("{commentId:guid}")]
    public async Task<IActionResult> DeleteComment(int postId, Guid commentId, CancellationToken cancellationToken = default)
    {
        var comment = await context.PostComments.SingleOrDefaultAsync(
            item => item.Id == commentId && item.PostId == postId, cancellationToken);
        if (comment is null) return NotFound();
        if (!CanMutate(comment)) return Forbid();

        context.PostComments.Remove(comment);
        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            return NotFound();
        }
        return NoContent();
    }

    private bool CanMutate(PostComment comment) =>
        !string.IsNullOrEmpty(UserId) && (comment.AuthorId == UserId || User.IsInRole("Admin"));

    private static bool ValidContent(string? content) =>
        !string.IsNullOrWhiteSpace(content) && content.Trim().Length <= 1000;

    private BadRequestObjectResult InvalidContent() =>
        BadRequest(new { message = "Bình luận phải có từ 1 đến 1000 ký tự và mã gửi hợp lệ." });

    private static IQueryable<CommentResponse> Responses(IQueryable<PostComment> comments) =>
        comments.AsNoTracking().Select(comment => new CommentResponse(
            comment.Id, comment.PostId, comment.AuthorId,
            comment.Author != null ? comment.Author.FullName : "User",
            comment.Content, comment.CreatedAt, comment.UpdatedAt));
}
