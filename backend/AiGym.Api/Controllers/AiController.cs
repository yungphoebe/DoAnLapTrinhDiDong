using AiGym.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AiGym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class AiController : ControllerBase
{
    private readonly ILmStudioService _lmStudioService;

    public AiController(ILmStudioService lmStudioService)
    {
        _lmStudioService = lmStudioService;
    }

    [HttpPost("chat")]
    public async Task<ActionResult<AiChatResponse>> Chat(
        AiChatRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Message))
        {
            return BadRequest(new { message = "Message is required." });
        }

        try
        {
            var reply = await _lmStudioService.ChatAsync(
                request.Message.Trim(),
                cancellationToken);
            return Ok(new AiChatResponse(reply));
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return StatusCode(StatusCodes.Status504GatewayTimeout, new
            {
                message = "LMStudio phản hồi quá chậm. Hãy thử câu hỏi ngắn hơn hoặc dùng model nhẹ hơn."
            });
        }
        catch (HttpRequestException)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                message = "LMStudio is unavailable. Start LMStudio and load the configured model."
            });
        }
        catch (InvalidOperationException)
        {
            return StatusCode(StatusCodes.Status502BadGateway, new
            {
                message = "LMStudio returned an invalid response."
            });
        }
    }
}

public sealed record AiChatRequest(string Message);

public sealed record AiChatResponse(string Reply);
