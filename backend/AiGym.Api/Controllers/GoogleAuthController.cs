using AiGym.Api.Models;
using AiGym.Api.Options;
using AiGym.Api.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace AiGym.Api.Controllers;

[ApiController]
[Route("api/auth/google")]
public sealed class GoogleAuthController(
    IOptions<GoogleAuthOptions> options,
    IGoogleTokenVerifier verifier,
    UserManager<ApplicationUser> users,
    JwtTokenService tokens) : ControllerBase
{
    [HttpGet("config")]
    public IActionResult Configuration() => string.IsNullOrWhiteSpace(options.Value.ClientId)
        ? Unconfigured()
        : Ok(new { clientId = options.Value.ClientId });

    [HttpPost]
    public async Task<IActionResult> Login(GoogleLoginRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(options.Value.ClientId)) return Unconfigured();
        if (string.IsNullOrWhiteSpace(request.IdToken) || request.IdToken.Length > 16384)
            return BadRequest(new { message = "Thiếu token đăng nhập Google hợp lệ." });
        GoogleIdentity identity;
        try
        {
            identity = await verifier.VerifyAsync(request.IdToken, cancellationToken);
        }
        catch (Exception error) when (error is SecurityTokenException or ArgumentException)
        {
            return Unauthorized(new { message = "Phiên Google không hợp lệ hoặc đã hết hạn. Vui lòng chọn tài khoản lại." });
        }
        catch (Exception error) when (error is HttpRequestException or InvalidOperationException)
        {
            return StatusCode(503, new { message = "Chưa thể xác minh với Google. Vui lòng thử lại sau." });
        }
        if (!identity.EmailVerified)
            return Unauthorized(new { message = "Địa chỉ email Google chưa được xác minh." });

        var user = await users.FindByLoginAsync("Google", identity.Subject);
        if (user is null)
        {
            // Matching email alone is not sufficient to link an existing password account.
            if (await users.FindByEmailAsync(identity.Email) is not null)
                return Conflict(new { message = "Email này đã có tài khoản AI GYM. Hãy đăng nhập bằng mật khẩu hiện có hoặc chọn tài khoản Google khác." });
            user = new ApplicationUser
            {
                UserName = identity.Email,
                Email = identity.Email,
                EmailConfirmed = true,
                FullName = identity.Name
            };
            var created = await users.CreateAsync(user);
            if (!created.Succeeded)
                return Conflict(new { message = "Chưa tạo được tài khoản. Vui lòng thử đăng nhập lại." });
            var role = await users.AddToRoleAsync(user, "User");
            var linked = role.Succeeded
                ? await users.AddLoginAsync(user, new UserLoginInfo("Google", identity.Subject, "Google"))
                : role;
            if (!linked.Succeeded)
            {
                await users.DeleteAsync(user);
                return Conflict(new { message = "Chưa liên kết được tài khoản Google. Vui lòng thử lại." });
            }
        }
        if (await users.IsLockedOutAsync(user))
            return Unauthorized(new { message = "Tài khoản đang bị khóa. Vui lòng thử lại sau." });
        return Ok(await tokens.CreateAuthResponseAsync(user));
    }

    private ObjectResult Unconfigured() => StatusCode(503,
        new { message = "Chưa cấu hình Google Client ID cho ứng dụng. Xem docs/GOOGLE_LOGIN.md." });
}

public sealed record GoogleLoginRequest(string IdToken);
