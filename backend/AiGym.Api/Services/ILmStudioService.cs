namespace AiGym.Api.Services;

public interface ILmStudioService
{
    Task<string> ChatAsync(
        string message, CancellationToken cancellationToken, string? context = null);
}
