namespace AiGym.Api.Models;

public sealed class UserFeedback
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = "";
    public string Subject { get; set; } = "";
    public string Content { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
