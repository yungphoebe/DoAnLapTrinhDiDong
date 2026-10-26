namespace AiGym.Api.Options;

public sealed class JwtOptions
{
    public string Issuer { get; set; } = "AiGym.Api";
    public string Audience { get; set; } = "AiGym.Mobile";
    public string Key { get; set; } = "AiGym.Dev.Secret.Key.Change.This.Before.Production.12345";
    public int ExpiresInMinutes { get; set; } = 120;
}
