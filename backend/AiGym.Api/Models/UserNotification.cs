namespace AiGym.Api.Models;

public sealed class UserNotification
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = "";
    public string Kind { get; set; } = "";
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public DateTime ScheduledAtUtc { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? ReadAt { get; set; }
    public long SettingsRevision { get; set; }
    public bool PushSent { get; set; }
    public int PushAttempts { get; set; }
    public DateTime? PushLeaseUntil { get; set; }
    public DateTime? NextPushUtc { get; set; }
}
