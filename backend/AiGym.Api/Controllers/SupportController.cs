using System.Security.Claims;
using AiGym.Api.Data;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

public sealed record FeedbackRequest(Guid RequestId, string? Subject, string? Content);

[ApiController,Route("api/support")]
public sealed class SupportController(ApplicationDbContext db,IConfiguration config) : ControllerBase
{
    [HttpGet("content")]
    public IActionResult ContentInfo() => Ok(new {
        groupName=config["SupportContent:GroupName"],guide=config["SupportContent:Guide"],
        terms=config["SupportContent:Terms"],privacy=config["SupportContent:Privacy"],
        updatedAt=config["SupportContent:UpdatedAt"]
    });

    [Authorize,HttpPost("feedback")]
    public async Task<IActionResult> Feedback(FeedbackRequest request)
    {
        if(request.RequestId==Guid.Empty || string.IsNullOrWhiteSpace(request.Content) || request.Content.Length>4000 || request.Subject?.Length>120)
            return BadRequest(new{message="Vui lòng nhập phản hồi từ 1 đến 4000 ký tự; tiêu đề tối đa 120 ký tự."});
        var userId=User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId")!;
        var existing=await db.UserFeedback.FindAsync(request.RequestId);
        if(existing is not null)
        {
            if(existing.UserId!=userId || existing.Content!=request.Content.Trim() || existing.Subject!=(request.Subject?.Trim() ?? "")) return Conflict();
            return Ok(new{id=existing.Id,createdAt=existing.CreatedAt});
        }
        var feedback=new UserFeedback{Id=request.RequestId,UserId=userId,Subject=request.Subject?.Trim() ?? "",Content=request.Content.Trim()};
        db.UserFeedback.Add(feedback);
        try {await db.SaveChangesAsync();}
        catch(DbUpdateException) {return Conflict(new{message="Yêu cầu đang được xử lý. Vui lòng thử lại."});}
        return StatusCode(201,new{id=feedback.Id,createdAt=feedback.CreatedAt});
    }
}
