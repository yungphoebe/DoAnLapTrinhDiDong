IF DB_ID(N'AIGymDb') IS NULL
BEGIN
    CREATE DATABASE [AIGymDb];
END;
GO

USE [AIGymDb];
GO

IF OBJECT_ID(N'dbo.Comments', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.Comments;
END;
GO

IF OBJECT_ID(N'dbo.Posts', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.Posts;
END;
GO

CREATE TABLE dbo.Posts
(
    Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Posts PRIMARY KEY,
    AuthorName NVARCHAR(100) NOT NULL,
    AvatarAsset NVARCHAR(255) NOT NULL,
    Content NVARCHAR(1000) NOT NULL,
    ImageAsset NVARCHAR(255) NULL,
    Tag NVARCHAR(50) NOT NULL CONSTRAINT DF_Posts_Tag DEFAULT N'Chia se',
    LikeCount INT NOT NULL CONSTRAINT DF_Posts_LikeCount DEFAULT 0,
    IsLiked BIT NOT NULL CONSTRAINT DF_Posts_IsLiked DEFAULT 0,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Posts_CreatedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dbo.Comments
(
    Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Comments PRIMARY KEY,
    PostId INT NOT NULL,
    AuthorName NVARCHAR(100) NOT NULL,
    Content NVARCHAR(500) NOT NULL,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Comments_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Comments_Posts FOREIGN KEY (PostId)
        REFERENCES dbo.Posts(Id)
        ON DELETE CASCADE
);
GO

INSERT INTO dbo.Posts
    (AuthorName, AvatarAsset, Content, ImageAsset, Tag, LikeCount, IsLiked, CreatedAt)
VALUES
    (
        N'Linh Nguyen',
        N'assets/images/avatar.jpg',
        N'Hom nay pha ky luc ca nhan Squat 100kg! Nho AI kiem tra form dung goc do cuc chuan luon.',
        N'assets/images/community.jpg',
        N'Chia se',
        128,
        0,
        DATEADD(HOUR, -2, SYSUTCDATETIME())
    ),
    (
        N'AI GYM Club',
        N'assets/images/trainer.jpg',
        N'Thu thach 7 ngay: moi ngay them 10 phut cardio sau buoi tap chinh.',
        NULL,
        N'Thu thach',
        47,
        0,
        DATEADD(HOUR, -5, SYSUTCDATETIME())
    );
GO

INSERT INTO dbo.Comments
    (PostId, AuthorName, Content, CreatedAt)
VALUES
    (
        1,
        N'Minh Anh',
        N'Qua dinh! Cung co gang nhe.',
        DATEADD(HOUR, -1, SYSUTCDATETIME())
    );
GO
