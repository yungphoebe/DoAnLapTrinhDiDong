namespace AiGym.Api.Models;

public sealed class BrowserPushSubscription
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string Endpoint { get; set; } = "";
    public string P256dh { get; set; } = "";
    public string Auth { get; set; } = "";
    public string SessionId { get; set; } = "";
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
