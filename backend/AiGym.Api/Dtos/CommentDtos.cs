namespace AiGym.Api.Dtos;

public sealed record CreateCommentRequest(Guid RequestId, string? Content);
public sealed record UpdateCommentRequest(string? Content);

public sealed record CommentResponse(
    Guid Id,
    int PostId,
    string AuthorId,
    string AuthorName,
    string Content,
    DateTime CreatedAt,
    DateTime? UpdatedAt);

public sealed record CommentPageResponse(
    IReadOnlyList<CommentResponse> Items,
    int Page,
    int PageSize,
    bool HasMore,
    int TotalCount);
