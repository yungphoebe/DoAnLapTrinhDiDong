namespace AiGym.Api.Models;

public sealed class PostComment
{
    public Guid Id { get; set; }
    public int PostId { get; set; }
    public Post? Post { get; set; }
    public string AuthorId { get; set; } = string.Empty;
    public ApplicationUser? Author { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}
