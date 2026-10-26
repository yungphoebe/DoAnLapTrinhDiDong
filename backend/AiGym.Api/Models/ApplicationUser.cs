using Microsoft.AspNetCore.Identity;

namespace AiGym.Api.Models;

public sealed class ApplicationUser : IdentityUser
{
    public string FullName { get; set; } = string.Empty;
    public double? HeightCm { get; set; }
    public double? WeightKg { get; set; }
    public int? Age { get; set; }
    public string? Gender { get; set; }
    public string? Goal { get; set; }
    public int? TrainingDays { get; set; }
    public string? TrainingLocation { get; set; }
    public string? TrainingLevel { get; set; }
}
