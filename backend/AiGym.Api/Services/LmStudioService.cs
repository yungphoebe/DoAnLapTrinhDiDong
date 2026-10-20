using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using AiGym.Api.Options;
using Microsoft.Extensions.Options;

namespace AiGym.Api.Services;

public sealed class LmStudioService : ILmStudioService
{
    private readonly HttpClient _httpClient;
    private readonly LmStudioOptions _options;

    public LmStudioService(HttpClient httpClient, IOptions<LmStudioOptions> options)
    {
        _httpClient = httpClient;
        _options = options.Value;
    }

    public async Task<string> ChatAsync(
        string message, CancellationToken cancellationToken, string? context = null)
    {
        var systemPrompt = string.IsNullOrWhiteSpace(context)
            ? "Ban la tro ly AI GYM, tra loi ngan gon, huu ich va an toan ve tap luyen, dinh duong."
            : $"Ban la tro ly AI GYM. Chi dung du lieu nguoi dung duoc cung cap de tham khao, khong tu biet them. {context}";
        var request = new
        {
            model = _options.Model,
            messages = new[]
            {
                new
                {
                    role = "system",
                    content = systemPrompt
                },
                new
                {
                    role = "user",
                    content = message
                }
            },
            temperature = 0.7
        };

        using var response = await _httpClient.PostAsJsonAsync(
            "chat/completions",
            request,
            cancellationToken);

        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException(
                $"LMStudio returned {(int)response.StatusCode}: {responseBody}");
        }

        var completion = JsonSerializer.Deserialize<LmStudioChatResponse>(responseBody);
        var content = completion?.Choices.FirstOrDefault()?.Message.Content;
        if (string.IsNullOrWhiteSpace(content))
        {
            throw new InvalidOperationException("LMStudio returned an empty chat response.");
        }

        return content.Trim();
    }

    private sealed record LmStudioChatResponse(
        [property: JsonPropertyName("choices")] IReadOnlyList<Choice> Choices);

    private sealed record Choice(
        [property: JsonPropertyName("message")] Message Message);

    private sealed record Message(
        [property: JsonPropertyName("content")] string Content);
}
