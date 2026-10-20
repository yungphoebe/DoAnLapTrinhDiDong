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
