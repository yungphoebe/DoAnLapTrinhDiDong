namespace AiGym.Api.Options;

public sealed class GoogleAuthOptions
{
    // Public OAuth Web Client ID. Never put a Client Secret in the web app.
    public string ClientId { get; set; } = string.Empty;
}
