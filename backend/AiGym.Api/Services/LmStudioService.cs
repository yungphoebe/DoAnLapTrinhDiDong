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
        var systemPrompt = "Ban la tro ly AI GYM. Tra loi bang tieng Viet, toi da 100 tu, " +
            "di thang vao cau hoi, khong lap lai ho so. Dung kien thuc tap luyen an toan de goi y. " +
            "Khong bia thong tin ca nhan hay lich tap cua nguoi noi tieng khi chua co nguon. " +
            $"Ho so va lich su chi de tham khao: {context}";
        var request = new
        {
            model = _options.Model,
            system_prompt = systemPrompt,
            input = message,
            // Prevent reasoning from consuming the entire answer budget.
            reasoning = "off",
            store = false,
            stream = false,
            temperature = 0.7,
            max_output_tokens = 256
        };

        using var response = await _httpClient.PostAsJsonAsync(
            "/api/v1/chat",
            request,
            cancellationToken);

        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException(
                $"LMStudio returned {(int)response.StatusCode}: {responseBody}");
        }

        LmStudioChatResponse? completion;
        try
        {
            completion = JsonSerializer.Deserialize<LmStudioChatResponse>(responseBody);
        }
        catch (JsonException exception)
        {
            throw new InvalidOperationException(
                "LMStudio returned a response that was not valid JSON.",
                exception);
        }

        var content = string.Join("\n", (completion?.Output ?? [])
            .Where(item => item.Type == "message" && !string.IsNullOrWhiteSpace(item.Content))
            .Select(item => item.Content!.Trim()));
        if (string.IsNullOrWhiteSpace(content))
        {
            throw new InvalidOperationException("LMStudio returned an empty chat response.");
        }

        return content.Trim();
    }

    private sealed record LmStudioChatResponse(
        [property: JsonPropertyName("output")] IReadOnlyList<OutputItem>? Output);

    private sealed record OutputItem(
        [property: JsonPropertyName("type")] string? Type,
        [property: JsonPropertyName("content")] string? Content);
}
