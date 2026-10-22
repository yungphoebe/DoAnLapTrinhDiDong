using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Data;
public static class SupportSchema
{
    public static Task EnsureAsync(ApplicationDbContext db)=>!db.Database.IsSqlServer()?Task.CompletedTask:db.Database.ExecuteSqlRawAsync("""
        IF OBJECT_ID(N'dbo.UserFeedback',N'U') IS NULL
        CREATE TABLE dbo.UserFeedback (
            Id uniqueidentifier NOT NULL PRIMARY KEY,
            UserId nvarchar(450) NOT NULL REFERENCES dbo.AspNetUsers(Id) ON DELETE CASCADE,
            Subject nvarchar(120) NOT NULL, Content nvarchar(4000) NOT NULL, CreatedAt datetime2 NOT NULL);
        """);
}
