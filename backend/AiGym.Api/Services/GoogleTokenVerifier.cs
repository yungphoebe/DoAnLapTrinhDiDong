using System.IdentityModel.Tokens.Jwt;
using AiGym.Api.Options;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

namespace AiGym.Api.Services;

public sealed record GoogleIdentity(string Subject, string Email, string Name, bool EmailVerified);

public interface IGoogleTokenVerifier
{
    Task<GoogleIdentity> VerifyAsync(string token, CancellationToken cancellationToken);
}

public sealed class GoogleTokenVerifier(
    IOptions<GoogleAuthOptions> options,
    IConfigurationManager<OpenIdConnectConfiguration> configurationManager) : IGoogleTokenVerifier
{
    public async Task<GoogleIdentity> VerifyAsync(string token, CancellationToken cancellationToken)
    {
        var configuration = await configurationManager.GetConfigurationAsync(cancellationToken);
        var parameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuers = ["https://accounts.google.com", "accounts.google.com"],
            ValidateAudience = true,
            ValidAudience = options.Value.ClientId,
            ValidateIssuerSigningKey = true,
            IssuerSigningKeys = configuration.SigningKeys,
            RequireSignedTokens = true,
            RequireExpirationTime = true,
            ValidateLifetime = true,
            ValidAlgorithms = [SecurityAlgorithms.RsaSha256],
            ClockSkew = TimeSpan.FromSeconds(30)
        };
        var handler = new JwtSecurityTokenHandler { MapInboundClaims = false };
        System.Security.Claims.ClaimsPrincipal principal;
        try
        {
            principal = handler.ValidateToken(token, parameters, out _);
        }
        catch (SecurityTokenSignatureKeyNotFoundException)
        {
            // Google rotates signing keys. Refresh before validating the next request.
            configurationManager.RequestRefresh();
            throw;
        }
        var subject = principal.FindFirst("sub")?.Value;
        var email = principal.FindFirst("email")?.Value;
        if (string.IsNullOrWhiteSpace(subject) || string.IsNullOrWhiteSpace(email))
            throw new SecurityTokenException("Google account has no subject or email.");
        return new GoogleIdentity(subject, email, principal.FindFirst("name")?.Value ?? email,
            bool.TryParse(principal.FindFirst("email_verified")?.Value, out var verified) && verified);
    }
}
