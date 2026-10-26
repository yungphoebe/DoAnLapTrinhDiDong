using AiGym.Api.Data;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Services;

public static class DatabaseSeeder
{
    public const string AdminEmail = "admin123@gmail.com";
    public const string AdminPassword = "123123123Az!";
    public const string VirtualFriendPassword = "Test123!Aa";

    public static async Task SeedAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        await context.Database.EnsureCreatedAsync();
        await PostLikesSchema.EnsureAsync(context);
        await CommentSchema.EnsureAsync(context);
        await NotificationSchema.EnsureAsync(context);
        await SupportSchema.EnsureAsync(context);
        await ChallengeSchema.EnsureAsync(context);
        try
        {
            if (context.Database.IsRelational())
                await context.Database.MigrateAsync();
        }
        catch (Microsoft.Data.SqlClient.SqlException)
        {
            // Tables already created by EnsureCreatedAsync
        }

        var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();
        foreach (var role in new[] { "Admin", "User" })
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new IdentityRole(role));
            }
        }

        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var admin = await userManager.FindByEmailAsync(AdminEmail);
        if (admin is null)
        {
            admin = new ApplicationUser
            {
                UserName = AdminEmail,
                Email = AdminEmail,
                EmailConfirmed = true,
                FullName = "AI GYM Admin"
            };
            var result = await userManager.CreateAsync(admin, AdminPassword);
            if (!result.Succeeded)
            {
                throw new InvalidOperationException(string.Join("; ", result.Errors.Select(error => error.Description)));
            }
        }

        if (!await userManager.IsInRoleAsync(admin, "Admin"))
        {
            await userManager.AddToRoleAsync(admin, "Admin");
        }

        if (IsDevelopment(services) && string.IsNullOrWhiteSpace(admin.TrainingLocation))
        {
            admin.TrainingLocation = "Gym Quận 1";
            admin.TrainingLevel ??= "Trung cấp";
            await userManager.UpdateAsync(admin);
        }

        if (IsDevelopment(services))
        {
            await SeedVirtualFriendsAsync(context, userManager);
        }

        if (!await context.Posts.AnyAsync())
        {
            context.Posts.AddRange(
                new Post
                {
                    AuthorId = admin.Id,
                    AuthorName = "Linh Nguyen",
                    Content = "Hom nay pha ky luc ca nhan Squat 100kg! Nho AI kiem tra form dung goc do cuc chuan luon.",
                    ImageAsset = "assets/images/community.jpg",
                    Tag = "Chia se",
                    CreatedAt = DateTime.UtcNow.AddHours(-2)
                },
                new Post
                {
                    AuthorId = admin.Id,
                    AuthorName = "AI GYM Club",
                    Content = "Thu thach 7 ngay: moi ngay them 10 phut cardio sau buoi tap chinh.",
                    Tag = "Thu thach",
                    CreatedAt = DateTime.UtcNow.AddHours(-5)
                });
            await context.SaveChangesAsync();
        }

        if (!await context.Exercises.AnyAsync())
        {
            context.Exercises.AddRange(
                new Exercise { Name = "Squat", Description = "Bodyweight squat", MuscleGroup = "Legs", Difficulty = "beginner" },
                new Exercise { Name = "Push-up", Description = "Standard push-up", MuscleGroup = "Chest", Difficulty = "beginner" },
                new Exercise { Name = "Jumping Jack", Description = "Full body cardio", MuscleGroup = "Full body", Difficulty = "beginner" });
            await context.SaveChangesAsync();
        }
        if (!await context.Foods.AnyAsync())
        {
            context.Foods.AddRange(
                new Food { Name = "Chicken breast", CaloriesPer100g = 165, ProteinPer100g = 31, CarbsPer100g = 0, FatPer100g = 3.6m },
                new Food { Name = "White rice", CaloriesPer100g = 130, ProteinPer100g = 2.7m, CarbsPer100g = 28, FatPer100g = .3m },
                new Food { Name = "Banana", CaloriesPer100g = 89, ProteinPer100g = 1.1m, CarbsPer100g = 23, FatPer100g = .3m });
            await context.SaveChangesAsync();
        }
    }

    private static bool IsDevelopment(IServiceProvider services)
        => services.GetRequiredService<IHostEnvironment>().IsDevelopment();

    private static async Task SeedVirtualFriendsAsync(
        ApplicationDbContext context,
        UserManager<ApplicationUser> userManager)
    {
        var virtualFriends = new[]
        {
            new
            {
                Email = "banao1@aigym.test",
                Name = "Nguyễn Minh Anh",
                Location = "Gym Quận 1",
                Level = "Trung cấp",
                Goal = "Tăng cơ",
                ChallengeId = "c4"
            },
            new
            {
                Email = "banao2@aigym.test",
                Name = "Trần Quốc Bảo",
                Location = "Gym Quận 1",
                Level = "Nâng cao",
                Goal = "Tăng sức mạnh",
                ChallengeId = "c2"
            },
            new
            {
                Email = "banao3@aigym.test",
                Name = "Lê Thu Hà",
                Location = "Gym Quận 3",
                Level = "Cơ bản",
                Goal = "Giảm cân",
                ChallengeId = "c1"
            },
            new
            {
                Email = "banao4@aigym.test",
                Name = "Phạm Đức Long",
                Location = "Gym Quận 7",
                Level = "Trung cấp",
                Goal = "Cải thiện thể lực",
                ChallengeId = "c6"
            }
        };

        foreach (var item in virtualFriends)
        {
            var user = await userManager.FindByEmailAsync(item.Email);
            if (user is null)
            {
                user = new ApplicationUser
                {
                    UserName = item.Email,
                    Email = item.Email,
                    EmailConfirmed = true,
                    FullName = item.Name,
                    TrainingLocation = item.Location,
                    TrainingLevel = item.Level,
                    Goal = item.Goal
                };
                var result = await userManager.CreateAsync(user, VirtualFriendPassword);
                if (!result.Succeeded)
                {
                    throw new InvalidOperationException(
                        string.Join("; ", result.Errors.Select(error => error.Description)));
                }
                await userManager.AddToRoleAsync(user, "User");
            }

            if (!await context.UserChallenges.AnyAsync(challenge =>
                    challenge.UserId == user.Id && challenge.ChallengeId == item.ChallengeId))
            {
                var definition = ChallengeCatalog.Get(item.ChallengeId);
                context.UserChallenges.Add(new UserChallenge
                {
                    UserId = user.Id,
                    ChallengeId = item.ChallengeId,
                    CurrentStepIndex = definition?.Steps.Count ?? 1,
                    CurrentProgress = definition?.Steps.Sum(step => step.TargetValue) ?? 1,
                    IsCompleted = true,
                    StartDate = DateTime.UtcNow.AddDays(-14),
                    CompletedAt = DateTime.UtcNow.AddDays(-1)
                });
            }
        }

        await context.SaveChangesAsync();
    }
}
