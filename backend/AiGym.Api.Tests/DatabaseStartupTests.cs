using AiGym.Api.Data;
using AiGym.Api.Models;
using AiGym.Api.Services;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;

namespace AiGym.Api.Tests;

public sealed class DatabaseStartupTests
{
    [SqlServerFact]
    public async Task Startup_UpgradesLegacyDatabaseWithoutHistory_AndPreservesUsers()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("AIGYM_TEST_SQLSERVER"))
        {
            InitialCatalog = $"AiGymStartupTest_{Guid.NewGuid():N}"
        };
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddDbContext<ApplicationDbContext>(options => options.UseSqlServer(connection.ConnectionString)
            .ConfigureWarnings(w => w.Ignore(RelationalEventId.PendingModelChangesWarning)));
        services.AddIdentity<ApplicationUser, Microsoft.AspNetCore.Identity.IdentityRole>()
            .AddEntityFrameworkStores<ApplicationDbContext>();
        await using var provider = services.BuildServiceProvider();
        await using var scope = provider.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        try
        {
            await db.GetService<IMigrator>().MigrateAsync("20261012153011_InitialCreate");
            await db.Database.ExecuteSqlRawAsync("""
                DELETE FROM __EFMigrationsHistory;
                INSERT INTO AspNetUsers (Id, FullName, EmailConfirmed, PhoneNumberConfirmed, TwoFactorEnabled, LockoutEnabled, AccessFailedCount)
                VALUES ('legacy-user', 'Existing user', 0, 0, 0, 0, 0);
                """);
            await DatabaseSeeder.SeedAsync(provider);
            await DatabaseSeeder.SeedAsync(provider);
            Assert.Equal("Existing user", (await db.Users.SingleAsync(u => u.Id == "legacy-user")).FullName);
            Assert.True(await db.Users.AnyAsync(u => u.Email == DatabaseSeeder.AdminEmail));
            Assert.NotEmpty(await db.Exercises.ToListAsync());
            Assert.NotEmpty(await db.Foods.ToListAsync());
            Assert.Empty(await db.Database.GetPendingMigrationsAsync());
        }
        finally
        {
            await db.Database.EnsureDeletedAsync();
        }
    }

    [SqlServerFact]
    public async Task Startup_CreatesFreshDatabase_AndCanRunAgain()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("AIGYM_TEST_SQLSERVER"))
        {
            InitialCatalog = $"AiGymFreshStartupTest_{Guid.NewGuid():N}"
        };
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddDbContext<ApplicationDbContext>(options => options.UseSqlServer(connection.ConnectionString)
            .ConfigureWarnings(w => w.Ignore(RelationalEventId.PendingModelChangesWarning)));
        services.AddIdentity<ApplicationUser, Microsoft.AspNetCore.Identity.IdentityRole>()
            .AddEntityFrameworkStores<ApplicationDbContext>();
        await using var provider = services.BuildServiceProvider();
        await using var scope = provider.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        try
        {
            await DatabaseSeeder.SeedAsync(provider);
            await DatabaseSeeder.SeedAsync(provider);
            Assert.Single(await db.Users.Where(u => u.Email == DatabaseSeeder.AdminEmail).ToListAsync());
            Assert.NotEmpty(await db.Exercises.ToListAsync());
            Assert.NotEmpty(await db.Foods.ToListAsync());
            Assert.Empty(await db.Database.GetPendingMigrationsAsync());
        }
        finally
        {
            await db.Database.EnsureDeletedAsync();
        }
    }
}
