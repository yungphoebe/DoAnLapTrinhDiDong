using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Data;

public static class ChallengeSchema
{
    public static async Task EnsureAsync(ApplicationDbContext db)
    {
        if (!db.Database.IsSqlServer()) return;

        await db.Database.ExecuteSqlRawAsync("""
            IF OBJECT_ID(N'dbo.UserChallenges', N'U') IS NULL
            BEGIN
                CREATE TABLE dbo.UserChallenges (
                    Id uniqueidentifier NOT NULL PRIMARY KEY,
                    UserId nvarchar(450) NOT NULL REFERENCES dbo.AspNetUsers(Id) ON DELETE CASCADE,
                    ChallengeId nvarchar(64) NOT NULL,
                    CurrentStepIndex int NOT NULL DEFAULT 0,
                    CurrentProgress int NOT NULL DEFAULT 0,
                    IsCompleted bit NOT NULL DEFAULT 0,
                    StartDate datetime2 NOT NULL,
                    CompletedAt datetime2 NULL,
                    LastProgressDate nvarchar(10) NULL,
                    DailyLogsJson nvarchar(max) NOT NULL DEFAULT '[]'
                );
                CREATE UNIQUE INDEX IX_UserChallenges_UserId_ChallengeId ON dbo.UserChallenges(UserId, ChallengeId);
            END
            ELSE
            BEGIN
                IF COL_LENGTH('dbo.UserChallenges', 'LastProgressDate') IS NULL
                    ALTER TABLE dbo.UserChallenges ADD LastProgressDate nvarchar(10) NULL;
                IF COL_LENGTH('dbo.UserChallenges', 'DailyLogsJson') IS NULL
                    ALTER TABLE dbo.UserChallenges ADD DailyLogsJson nvarchar(max) NOT NULL DEFAULT '[]';
            END
            """);
    }
}
