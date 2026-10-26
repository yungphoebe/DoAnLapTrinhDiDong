namespace AiGym.Api.Models;

public sealed class PostLike
{
    public int PostId { get; set; }
    public Post Post { get; set; } = null!;
    public string UserId { get; set; } = string.Empty;
}
