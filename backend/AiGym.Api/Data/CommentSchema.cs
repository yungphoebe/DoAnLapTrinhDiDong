using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Data;

public static class CommentSchema
{
    // EnsureCreated cannot add tables to an existing application database.
    public static Task EnsureAsync(ApplicationDbContext context) =>
        context.Database.IsSqlServer()
            ? context.Database.ExecuteSqlRawAsync("""
                IF OBJECT_ID(N'dbo.PostComments', N'U') IS NULL
                BEGIN
                    CREATE TABLE dbo.PostComments (
                        Id uniqueidentifier NOT NULL,
                        PostId int NOT NULL,
                        AuthorId nvarchar(450) NOT NULL,
                        Content nvarchar(1000) NOT NULL,
                        CreatedAt datetime2 NOT NULL,
                        UpdatedAt datetime2 NULL,
                        CONSTRAINT PK_PostComments PRIMARY KEY (Id),
                        CONSTRAINT FK_PostComments_Posts_PostId FOREIGN KEY (PostId)
                            REFERENCES dbo.Posts(Id) ON DELETE CASCADE,
                        CONSTRAINT FK_PostComments_AspNetUsers_AuthorId FOREIGN KEY (AuthorId)
                            REFERENCES dbo.AspNetUsers(Id)
                    );
                    CREATE INDEX IX_PostComments_AuthorId ON dbo.PostComments(AuthorId);
                    CREATE INDEX IX_PostComments_PostId_CreatedAt_Id
                        ON dbo.PostComments(PostId, CreatedAt, Id);
                END
                """)
            : Task.CompletedTask;
}
