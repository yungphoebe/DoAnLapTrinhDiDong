using System.Net;
using System.Text;
using System.Text.Json;
using AiGym.Api.Options;
using AiGym.Api.Services;
using OptionsFactory = Microsoft.Extensions.Options.Options;

namespace AiGym.Api.Tests;

public sealed class LmStudioServiceTests
{
    [Fact]
    public async Task Chat_ReturnsAnswerWithReasoningDisabledAndPreservesContext()
    {
        using var handler = new ResponseHandler("""
            {"output":[{"type":"reasoning","content":"internal"},
                       {"type":"message","content":"  Xin chào!  "},
                       {"type":"message","content":"Hãy khởi động trước khi tập."}]}
            """);
        using var client = new HttpClient(handler) { BaseAddress = new Uri("http://localhost:1234/v1/") };
        var service = new LmStudioService(client, OptionsFactory.Create(new LmStudioOptions { Model = "qwen/qwen3.5-9b" }));

        var reply = await service.ChatAsync("Bài tập nào?", CancellationToken.None, "Mục tiêu: tăng cơ");

        Assert.Equal("Xin chào!\nHãy khởi động trước khi tập.", reply);
        Assert.Equal("/api/v1/chat", handler.Uri!.AbsolutePath);
        using var body = JsonDocument.Parse(handler.Body!);
        Assert.Equal("off", body.RootElement.GetProperty("reasoning").GetString());
        Assert.False(body.RootElement.GetProperty("stream").GetBoolean());
        Assert.False(body.RootElement.GetProperty("store").GetBoolean());
        Assert.Equal("qwen/qwen3.5-9b", body.RootElement.GetProperty("model").GetString());
        Assert.Equal("Bài tập nào?", body.RootElement.GetProperty("input").GetString());
        Assert.Contains("Mục tiêu: tăng cơ", body.RootElement.GetProperty("system_prompt").GetString());
    }

    [Theory]
    [InlineData("not json")]
    [InlineData("{}")]
    [InlineData("{\"output\":null}")]
    [InlineData("{\"output\":[]}")]
    [InlineData("{\"output\":[{\"type\":\"message\",\"content\":\"  \"}]}")]
    [InlineData("{\"output\":[{\"type\":\"reasoning\",\"content\":\"internal\"}]}")]
    public async Task Chat_RejectsResponsesWithoutAnAnswer(string response)
    {
        using var handler = new ResponseHandler(response);
        using var client = new HttpClient(handler) { BaseAddress = new Uri("http://localhost:1234/v1/") };
        var service = new LmStudioService(client, OptionsFactory.Create(new LmStudioOptions()));

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.ChatAsync("Hi", CancellationToken.None));
    }

    private sealed class ResponseHandler(string response) : HttpMessageHandler
    {
        public Uri? Uri { get; private set; }
        public string? Body { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Uri = request.RequestUri;
            Body = await request.Content!.ReadAsStringAsync(cancellationToken);
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(response, Encoding.UTF8, "application/json")
            };
        }
    }
}
