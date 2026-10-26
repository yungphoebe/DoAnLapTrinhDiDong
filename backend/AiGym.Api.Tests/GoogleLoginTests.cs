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

    [Fact]
    public async Task GoogleSession_CanSaveActivityAndWorkout_WithoutSharingAnotherAccountsHistory()
    {
        using var factory = new ApiFactory();
        using var app = factory.WithWebHostBuilder(b => b.ConfigureTestServices(s =>
        {
            s.Configure<GoogleAuthOptions>(o => o.ClientId = ClientId);
            s.AddSingleton<IGoogleTokenVerifier>(new FakeVerifier());
        }));
        using var client = app.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/google", new { idToken = "valid" });
        response.EnsureSuccessStatusCode();
        var auth = await response.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.GetProperty("token").GetString());
        var activityId = Guid.NewGuid();
        var activity = await client.PostAsJsonAsync("/api/activity/sessions", new
        {
            id = activityId, activityType = "walking", startedAt = DateTimeOffset.UtcNow.AddMinutes(-10),
            durationSeconds = 600, steps = 800, distanceMeters = 600, completed = true, distanceEstimated = true
        });
        Assert.Equal(HttpStatusCode.Created, activity.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await client.PostAsJsonAsync("/api/profile/workouts", new
        {
            id = Guid.NewGuid(), durationSeconds = 120, startedAt = DateTimeOffset.UtcNow.AddMinutes(-5)
        })).StatusCode);
        var sessions = await client.GetFromJsonAsync<JsonElement>("/api/activity/sessions");
        Assert.Equal(activityId, sessions[0].GetProperty("id").GetGuid());
        var again = await client.PostAsJsonAsync("/api/auth/google", new { idToken = "valid" });
        again.EnsureSuccessStatusCode();
        Assert.Equal(auth.GetProperty("userId").GetString(), (await again.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("userId").GetString());
        using var other = app.CreateClient();
        var register = await other.PostAsJsonAsync("/api/auth/register", new
        {
            fullName = "Other user", email = "other-activity@example.com", password = "123123123Az!"
        });
        register.EnsureSuccessStatusCode();
        var otherAuth = await register.Content.ReadFromJsonAsync<JsonElement>();
        other.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", otherAuth.GetProperty("token").GetString());
        Assert.Equal(0, (await other.GetFromJsonAsync<JsonElement>("/api/activity/sessions")).GetArrayLength());
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
