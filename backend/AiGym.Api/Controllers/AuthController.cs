using System.Security.Claims;
using AiGym.Api.Dtos;
using AiGym.Api.Models;
using AiGym.Api.Options;
using AiGym.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace AiGym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class AuthController : ControllerBase
{
    private readonly JwtTokenService _jwtTokenService;
    private readonly IEmailSender _emailSender;
    private readonly SmtpOptions _smtpOptions;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly UserManager<ApplicationUser> _userManager;

    public AuthController(
        UserManager<ApplicationUser> userManager,
        SignInManager<ApplicationUser> signInManager,
        JwtTokenService jwtTokenService,
        IEmailSender emailSender,
        IOptions<SmtpOptions> smtpOptions)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _jwtTokenService = jwtTokenService;
        _emailSender = emailSender;
        _smtpOptions = smtpOptions.Value;
    }

    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.FullName) ||
            string.IsNullOrWhiteSpace(request.Email) ||
            string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new { message = "Full name, email and password are required." });
        }

        var existing = await _userManager.FindByEmailAsync(request.Email);
        if (existing is not null)
        {
            return Conflict(new { message = "Email already exists." });
        }

        var user = new ApplicationUser
        {
            UserName = request.Email.Trim(),
            Email = request.Email.Trim(),
            EmailConfirmed = true,
            FullName = request.FullName.Trim()
        };

        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
        {
            return BadRequest(new { errors = result.Errors.Select(error => error.Description) });
        }

        await _userManager.AddToRoleAsync(user, "User");
        return Ok(await _jwtTokenService.CreateAuthResponseAsync(user));
    }

    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(new { message = "Email is required." });
        }

        var email = request.Email.Trim();
        var user = await _userManager.FindByEmailAsync(email);
        if (user is not null)
        {
            var token = await _userManager.GeneratePasswordResetTokenAsync(user);
            var body = BuildResetPasswordEmail(email, token, request.ResetBaseUrl);
            await _emailSender.SendAsync(email, "AI GYM - Dat lai mat khau", body);
        }

        return Ok(new { message = "Neu email ton tai, huong dan dat lai mat khau da duoc gui." });
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) ||
            string.IsNullOrWhiteSpace(request.Token) ||
            string.IsNullOrWhiteSpace(request.NewPassword))
        {
            return BadRequest(new { message = "Email, token and new password are required." });
        }

        var user = await _userManager.FindByEmailAsync(request.Email.Trim());
        if (user is null)
        {
            return BadRequest(new { message = "Token dat lai mat khau khong hop le." });
        }

        var result = await _userManager.ResetPasswordAsync(user, request.Token, request.NewPassword);
        if (!result.Succeeded)
        {
            return BadRequest(new { errors = result.Errors.Select(error => error.Description) });
        }

        return Ok(new { message = "Mat khau da duoc cap nhat." });
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request)
    {
        var user = await _userManager.FindByEmailAsync(request.Email.Trim());
        if (user is null)
        {
            return Unauthorized(new { message = "Email or password is incorrect." });
        }

        var result = await _signInManager.CheckPasswordSignInAsync(user, request.Password, lockoutOnFailure: false);
        if (!result.Succeeded)
        {
            return Unauthorized(new { message = "Email or password is incorrect." });
        }

        return Ok(await _jwtTokenService.CreateAuthResponseAsync(user));
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult<MeResponse>> Me()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");
        if (userId is null)
        {
            return Unauthorized();
        }

        var user = await _userManager.FindByIdAsync(userId);
        if (user is null)
        {
            return Unauthorized();
        }

        var role = User.FindFirstValue("role") ?? User.FindFirstValue(ClaimTypes.Role) ?? "User";
        var expiresAt = DateTimeOffset.FromUnixTimeSeconds(long.Parse(User.FindFirstValue("exp") ?? "0")).UtcDateTime;
        return Ok(new MeResponse(user.Id, user.Email ?? string.Empty, user.FullName, role, expiresAt));
    }

    private string BuildResetPasswordEmail(string email, string token, string? resetBaseUrl)
    {
        var encodedEmail = Uri.EscapeDataString(email);
        var encodedToken = Uri.EscapeDataString(token);
        var baseUrl = string.IsNullOrWhiteSpace(resetBaseUrl)
            ? _smtpOptions.ResetBaseUrl
            : resetBaseUrl;
        var link = string.IsNullOrWhiteSpace(baseUrl)
            ? string.Empty
            : $"{baseUrl.TrimEnd('/')}?email={encodedEmail}&token={encodedToken}";

        return string.Join(
            Environment.NewLine,
            "Ban vua yeu cau dat lai mat khau AI GYM.",
            string.IsNullOrWhiteSpace(link)
                ? "Dung token ben duoi de dat mat khau moi trong ung dung hoac Swagger."
                : "Bam link ben duoi de tao mat khau moi.",
            $"Email: {email}",
            $"Reset token: {token}",
            string.IsNullOrWhiteSpace(link) ? string.Empty : $"Link: {link}",
            "Neu ban khong yeu cau, hay bo qua email nay.");
    }
}
