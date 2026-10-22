using System.ComponentModel.DataAnnotations;

namespace AiGym.Api.Dtos;

public sealed record CreatePostRequest(string Content, string? ImageAsset = null, string? Tag = null);

public sealed record UpdatePostRequest(string Content);

public sealed record SetPostLikeRequest([Required] bool? Liked);

public sealed record PostLikeResponse(int PostId, bool Liked, int LikeCount);

public sealed record PostPageResponse(IReadOnlyList<PostResponse> Items, int Page, int PageSize, bool HasMore);

public sealed record PostResponse(
    int Id,
    string AuthorId,
    string AuthorName,
    string Content,
    string? ImageAsset,
    string Tag,
    int LikeCount,
    bool Liked,
    DateTime CreatedAt,
    int CommentCount = 0);
