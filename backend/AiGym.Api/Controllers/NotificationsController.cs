using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using AiGym.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

[ApiController, Authorize, Route("api/notifications")]
public sealed class NotificationsController(ApplicationDbContext db, NotificationScheduler scheduler, NotificationPush push) : ControllerBase
{
    private string UserId => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId")!;

    [HttpGet("settings")]
    public async Task<IActionResult> GetSettings() => Ok(ReminderSettingsDto.From(
        await db.ReminderSettings.AsNoTracking().SingleOrDefaultAsync(s => s.UserId == UserId) ?? new ReminderSettings { UserId = UserId }));

    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(ReminderSettingsDto request)
    {
        if (!request.Valid()) return BadRequest(new { message = "Lịch nhắc hoặc múi giờ không hợp lệ." });
        var settings = await db.ReminderSettings.FindAsync(UserId);
        if (settings is null) { settings = new ReminderSettings { UserId = UserId }; db.ReminderSettings.Add(settings); }
        if (request.Revision != settings.Revision) return Conflict(new { message = "Cài đặt đã thay đổi. Vui lòng tải lại." });
        request.Apply(settings); settings.Revision++; settings.UpdatedAt = DateTime.UtcNow;
        settings.LastProcessedUtc = settings.UpdatedAt;
        try { await db.SaveChangesAsync(); }
        catch (DbUpdateException) { return Conflict(new { message = "Cài đặt đã thay đổi. Vui lòng tải lại." }); }
        return Ok(ReminderSettingsDto.From(settings));
    }

    [HttpGet]
    public async Task<IActionResult> List(int page = 1, int pageSize = 20)
    {
        if (page < 1 || pageSize < 1 || pageSize > 100 || (long)page * pageSize > int.MaxValue) return BadRequest();
        await scheduler.TickAsync(DateTime.UtcNow, UserId);
        var own = db.UserNotifications.AsNoTracking().Where(n => n.UserId == UserId);
        var items = await own.OrderByDescending(n => n.ScheduledAtUtc).ThenBy(n => n.Id).Skip((page - 1) * pageSize).Take(pageSize + 1)
            .Select(n => new { n.Id, n.Kind, n.Title, n.Body, n.ScheduledAtUtc, n.ReadAt }).ToListAsync();
        return Ok(new { items = items.Take(pageSize), page, pageSize, hasMore = items.Count > pageSize,
            unreadCount = await own.CountAsync(n => n.ReadAt == null) });
    }

    [HttpPut("{id:guid}/read")]
    public async Task<IActionResult> Read(Guid id)
    {
        var n = await db.UserNotifications.SingleOrDefaultAsync(n => n.Id == id && n.UserId == UserId);
        if (n is null) return NotFound();
        n.ReadAt ??= DateTime.UtcNow; await db.SaveChangesAsync(); return NoContent();
    }

    [HttpPut("read-all")]
    public async Task<IActionResult> ReadAll()
    {
        var unread = await db.UserNotifications.Where(n => n.UserId == UserId && n.ReadAt == null).ToListAsync();
        foreach (var n in unread) n.ReadAt = DateTime.UtcNow;
        await db.SaveChangesAsync(); return NoContent();
    }

    [HttpGet("push-key")]
    public IActionResult PublicKey() => Ok(new { publicKey = push.PublicKey });

    [HttpPost("subscriptions")]
    public async Task<IActionResult> Subscribe(PushSubscriptionRequest request)
    {
        if (!NotificationPush.ValidSubscription(request)) return BadRequest(new { message = "Đăng ký trình duyệt không hợp lệ." });
        var id = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(request.Endpoint)));
        var subscription = await db.BrowserPushSubscriptions.FindAsync(id);
        if (subscription is null) { subscription = new BrowserPushSubscription { Id = id }; db.Add(subscription); }
        else if (subscription.UserId != UserId && (subscription.P256dh != request.P256dh || subscription.Auth != request.Auth)) return Conflict();
        subscription.UserId = UserId; subscription.Endpoint = request.Endpoint; subscription.P256dh = request.P256dh;
        subscription.Auth = request.Auth; subscription.SessionId = request.SessionId; subscription.UpdatedAt = DateTime.UtcNow;
        try { await db.SaveChangesAsync(); } catch (DbUpdateException) { return Conflict(); }
        return NoContent();
    }

    [HttpDelete("subscriptions")]
    public async Task<IActionResult> Unsubscribe([FromBody] RemoveSubscriptionRequest request)
    {
        var subscription = await db.BrowserPushSubscriptions.SingleOrDefaultAsync(s => s.Endpoint == request.Endpoint && s.UserId == UserId);
        if (subscription is not null) { db.Remove(subscription); await db.SaveChangesAsync(); }
        return NoContent();
    }
}
