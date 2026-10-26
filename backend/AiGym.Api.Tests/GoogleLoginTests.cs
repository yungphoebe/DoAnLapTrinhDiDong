using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.Json;
using AiGym.Api.Options;
using AiGym.Api.Services;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

namespace AiGym.Api.Tests;

public sealed class GoogleLoginTests
{
    private const string ClientId = "test.apps.googleusercontent.com";

    [Fact]
    public async Task MissingConfiguration_Returns503_InsteadOfAcceptingToken()
    {
        using var factory = new ApiFactory();
        using var app = factory.WithWebHostBuilder(b => b.ConfigureTestServices(s =>
            s.Configure<GoogleAuthOptions>(o => o.ClientId = "")));
        using var client = app.CreateClient();
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await client.GetAsync("/api/auth/google/config")).StatusCode);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await client.PostAsJsonAsync("/api/auth/google", new { idToken = "fake" })).StatusCode);
    }

    [Fact]
    public async Task VerifiedGoogleUser_CreatesUserRoleSession_AndReturnsSameAccount()
    {
        using var factory = new ApiFactory();
        using var app = factory.WithWebHostBuilder(b => b.ConfigureTestServices(s =>
        {
            s.Configure<GoogleAuthOptions>(o => o.ClientId = ClientId);
            s.AddSingleton<IGoogleTokenVerifier>(new FakeVerifier());
        }));
        using var client = app.CreateClient();
        var config = await client.GetFromJsonAsync<JsonElement>("/api/auth/google/config");
        Assert.Equal(ClientId, config.GetProperty("clientId").GetString());
        var first = await client.PostAsJsonAsync("/api/auth/google", new { idToken = "valid" });
        first.EnsureSuccessStatusCode();
        var auth = await first.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("User", auth.GetProperty("role").GetString());
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.GetProperty("token").GetString());
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/auth/me")).StatusCode);
        var again = await client.PostAsJsonAsync("/api/auth/google", new { idToken = "valid" });
        again.EnsureSuccessStatusCode();
        Assert.Equal(auth.GetProperty("userId").GetString(), (await again.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("userId").GetString());
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/auth/google", new { idToken = "forged" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/auth/google", new { idToken = "unverified" })).StatusCode);
    }

    [Fact]
    public async Task MatchingEmail_DoesNotTakeOverPasswordAccount()
    {
        using var factory = new ApiFactory();
        using var app = factory.WithWebHostBuilder(b => b.ConfigureTestServices(s =>
        {
            s.Configure<GoogleAuthOptions>(o => o.ClientId = ClientId);
            s.AddSingleton<IGoogleTokenVerifier>(new FakeVerifier());
        }));
        using var client = app.CreateClient();
        (await client.PostAsJsonAsync("/api/auth/register", new { fullName = "Existing", email = "person@gmail.com", password = "123123123Az!" })).EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsJsonAsync("/api/auth/google", new { idToken = "valid" })).StatusCode);
    }

    [Theory]
    [InlineData("valid")]
    [InlineData("wrong-audience")]
    [InlineData("wrong-issuer")]
    [InlineData("expired")]
    [InlineData("forged")]
    public async Task Verifier_ChecksSignatureAudienceIssuerAndExpiry(string scenario)
    {
        using var rsa = RSA.Create(2048);
        using var attacker = RSA.Create(2048);
        var key = new RsaSecurityKey(rsa) { KeyId = "google-test" };
        var configuration = new OpenIdConnectConfiguration();
        configuration.SigningKeys.Add(key);
        var verifier = new GoogleTokenVerifier(Microsoft.Extensions.Options.Options.Create(new GoogleAuthOptions { ClientId = ClientId }), new StaticConfigurationManager<OpenIdConnectConfiguration>(configuration));
        var now = DateTime.UtcNow;
        var token = new JwtSecurityToken(
            scenario == "wrong-issuer" ? "https://attacker.example" : "https://accounts.google.com",
            scenario == "wrong-audience" ? "other-client" : ClientId,
            [new Claim("sub", "subject-1"), new Claim("email", "person@gmail.com"), new Claim("email_verified", "true", ClaimValueTypes.Boolean), new Claim("name", "Google User")],
            now.AddMinutes(-10), scenario == "expired" ? now.AddMinutes(-5) : now.AddMinutes(10),
            new SigningCredentials(scenario == "forged" ? new RsaSecurityKey(attacker) { KeyId = key.KeyId } : key, SecurityAlgorithms.RsaSha256));
        var encoded = new JwtSecurityTokenHandler().WriteToken(token);
        if (scenario == "valid")
        {
            var result = await verifier.VerifyAsync(encoded, default);
            Assert.Equal("subject-1", result.Subject);
            Assert.True(result.EmailVerified);
        }
        else await Assert.ThrowsAnyAsync<SecurityTokenException>(() => verifier.VerifyAsync(encoded, default));
    }

    private sealed class FakeVerifier : IGoogleTokenVerifier
    {
        public Task<GoogleIdentity> VerifyAsync(string token, CancellationToken cancellationToken)
        {
            if (token == "forged") throw new SecurityTokenException("Invalid token");
            return Task.FromResult(new GoogleIdentity("subject-1", "person@gmail.com", "Google User", token != "unverified"));
        }
    }
}
