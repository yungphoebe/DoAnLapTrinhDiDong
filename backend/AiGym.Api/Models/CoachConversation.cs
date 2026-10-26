namespace AiGym.Api.Models;

public sealed class CoachConversation
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public ApplicationUser User { get; set; } = null!;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public ICollection<CoachMessage> Messages { get; set; } = new List<CoachMessage>();
}

public sealed class CoachMessage
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ConversationId { get; set; }
    public CoachConversation Conversation { get; set; } = null!;
    public string Sender { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string Status { get; set; } = "completed";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
