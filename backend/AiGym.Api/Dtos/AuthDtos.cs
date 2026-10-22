namespace AiGym.Api.Dtos;

public sealed record RegisterRequest(string FullName, string Email, string Password);

public sealed record LoginRequest(string Email, string Password);

public sealed record ForgotPasswordRequest(string Email, string? ResetBaseUrl = null);

public sealed record ResetPasswordRequest(string Email, string Token, string NewPassword);

public sealed record AuthResponse(
    string Token,
    string UserId,
    string Email,
    string FullName,
    string Role,
    DateTime ExpiresAt);

public sealed record MeResponse(string UserId, string Email, string FullName, string Role, DateTime ExpiresAt);
