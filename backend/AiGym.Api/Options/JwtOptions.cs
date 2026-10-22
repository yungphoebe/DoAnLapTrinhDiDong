namespace AiGym.Api.Options;

public sealed class JwtOptions
{
    public string Issuer { get; set; } = "AiGym.Api";
    public string Audience { get; set; } = "AiGym.Mobile";
    public string Key { get; set; } = "CHANGE_THIS_TO_A_LONG_RANDOM_SECRET";
    public int ExpiresInMinutes { get; set; } = 120;
}
