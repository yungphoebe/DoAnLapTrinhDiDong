using Microsoft.AspNetCore.Identity;

namespace AiGym.Api.Models;

public sealed class ApplicationUser : IdentityUser
{
    public string FullName { get; set; } = string.Empty;
}
