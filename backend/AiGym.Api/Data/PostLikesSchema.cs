using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Data;

public static class PostLikesSchema
{
    // EnsureCreated does not add tables to databases that already exist.
    public static Task EnsureAsync(ApplicationDbContext context) =>
        context.Database.IsSqlServer()
            ? context.Database.ExecuteSqlRawAsync("""
                IF OBJECT_ID(N'dbo.PostLikes', N'U') IS NULL
                BEGIN
                    CREATE TABLE dbo.PostLikes (
                        PostId int NOT NULL,
                        UserId nvarchar(450) NOT NULL,
                        CONSTRAINT PK_PostLikes PRIMARY KEY (PostId, UserId),
                        CONSTRAINT FK_PostLikes_Posts_PostId FOREIGN KEY (PostId)
                            REFERENCES dbo.Posts(Id) ON DELETE CASCADE,
                        CONSTRAINT FK_PostLikes_AspNetUsers_UserId FOREIGN KEY (UserId)
                            REFERENCES dbo.AspNetUsers(Id)
                    );
                    CREATE INDEX IX_PostLikes_UserId ON dbo.PostLikes(UserId);
                END
                """)
            : Task.CompletedTask;
}
