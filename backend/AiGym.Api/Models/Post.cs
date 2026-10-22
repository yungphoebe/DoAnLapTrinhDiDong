namespace AiGym.Api.Models;

public sealed class Post
{
    public int Id { get; set; }
    public string AuthorId { get; set; } = string.Empty;
    public ApplicationUser? Author { get; set; }
    public string AuthorName { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string? ImageAsset { get; set; }
    public string Tag { get; set; } = "Chia se";
    public int LikeCount { get; set; }
    public bool Liked { get; set; }
    public ICollection<PostLike> Likes { get; set; } = new List<PostLike>();
    public ICollection<PostComment> Comments { get; set; } = new List<PostComment>();
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
