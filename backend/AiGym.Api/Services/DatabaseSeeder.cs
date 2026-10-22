using AiGym.Api.Data;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Services;

public static class DatabaseSeeder
{
    public const string AdminEmail = "admin123@gmail.com";
    public const string AdminPassword = "123123123Az!";

    public static async Task SeedAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        await context.Database.EnsureCreatedAsync();
        await PostLikesSchema.EnsureAsync(context);
        await CommentSchema.EnsureAsync(context);
        await NotificationSchema.EnsureAsync(context);
        await SupportSchema.EnsureAsync(context);

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
    }
}
