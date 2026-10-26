using System.Data;
using System.Data.Common;
using System.Security.Claims;
using AiGym.Api.Data;
using AiGym.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Controllers;

// ═════════════════════════════════════════════════════════════════════════════
// 1. DTO MODELS
// ═════════════════════════════════════════════════════════════════════════════

public class FriendUserDto
{
    public string Id { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? TrainingLevel { get; set; }
    public string? Goal { get; set; }
    public int CompletedChallengesCount { get; set; }
    public int WonDuelsCount { get; set; }
    public int ActiveDuelsCount { get; set; }
    public string Status { get; set; } = "Friend";
    public Guid? FriendshipId { get; set; }
}

public class FriendRequestDto
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? TrainingLevel { get; set; }
    public bool IsIncoming { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class SendFriendRequestInput
{
    public string? TargetUserId { get; set; }
    public string? TargetEmail { get; set; }
}

public class CreateDuelInput
{
    public string OpponentId { get; set; } = string.Empty;
    public string ChallengeId { get; set; } = string.Empty;
    public int TargetValue { get; set; }
    public string? Notes { get; set; }
}

public class UpdateDuelProgressInput
{
    public int Amount { get; set; }
}

public class DuelItemDto
{
    public Guid Id { get; set; }
    public string ChallengeId { get; set; } = string.Empty;
    public string ChallengeTitle { get; set; } = string.Empty;
    public string ChallengeEmoji { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public int TargetValue { get; set; }
    public string Unit { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string CreatorId { get; set; } = string.Empty;
    public string CreatorName { get; set; } = string.Empty;
    public int CreatorProgress { get; set; }
    public string OpponentId { get; set; } = string.Empty;
    public string OpponentName { get; set; } = string.Empty;
    public int OpponentProgress { get; set; }
    public string? WinnerId { get; set; }
    public string? WinnerName { get; set; }
    public bool IsCreator { get; set; }
    public int MyProgress { get; set; }
    public int OpponentProgressForMe { get; set; }
    public bool IsMyTurn { get; set; }
    public bool IsWonByMe { get; set; }
}

public class LeaderboardItemDto
{
    public int Rank { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string? TrainingLevel { get; set; }
    public int CompletedChallenges { get; set; }
    public int WonDuels { get; set; }
    public int Score { get; set; }
    public bool IsCurrentUser { get; set; }
    public bool IsFriend { get; set; }
}

public class MedalDto
{
    public string ChallengeId { get; set; } = string.Empty;
    public string ChallengeTitle { get; set; } = string.Empty;
    public string MedalTitle { get; set; } = string.Empty;
    public string MedalDescription { get; set; } = string.Empty;
    public string Emoji { get; set; } = string.Empty;
    public string Difficulty { get; set; } = "Medium";
    public int Points { get; set; }
    public bool Earned { get; set; }
    public DateTime? EarnedAt { get; set; }
    public int CurrentProgress { get; set; }
    public int TotalSteps { get; set; }
    public int CompletedSteps { get; set; }
}

public class MedalCompareItemDto
{
    public string ChallengeId { get; set; } = string.Empty;
    public string ChallengeTitle { get; set; } = string.Empty;
    public string MedalTitle { get; set; } = string.Empty;
    public string MedalDescription { get; set; } = string.Empty;
    public string Emoji { get; set; } = string.Empty;
    public string Difficulty { get; set; } = "Medium";
    public int Points { get; set; }

    public bool MyEarned { get; set; }
    public DateTime? MyEarnedAt { get; set; }

    public bool FriendEarned { get; set; }
    public DateTime? FriendEarnedAt { get; set; }
}

public class MedalCompareDto
{
    public string MyUserId { get; set; } = string.Empty;
    public string MyName { get; set; } = string.Empty;
    public int MyTotalPoints { get; set; }
    public int MyMedalsCount { get; set; }

    public string FriendUserId { get; set; } = string.Empty;
    public string FriendName { get; set; } = string.Empty;
    public int FriendTotalPoints { get; set; }
    public int FriendMedalsCount { get; set; }

    public int TotalAvailableMedals { get; set; }
    public List<MedalCompareItemDto> Items { get; set; } = new();
}

public class MedalLeaderboardItemDto
{
    public int Rank { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string? TrainingLevel { get; set; }
    public int MedalsCount { get; set; }
    public int TotalPoints { get; set; }
    public bool IsCurrentUser { get; set; }
    public bool IsFriend { get; set; }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. DATA ACCESS & SCHEMA
// ═════════════════════════════════════════════════════════════════════════════

internal static class FriendsCompetitionDataHelper
{
    private static bool _initialized = false;
    private static readonly SemaphoreSlim _semaphore = new(1, 1);

    public static async Task EnsureSchemaAsync(ApplicationDbContext db)
    {
        if (_initialized) return;
        await _semaphore.WaitAsync();
        try
        {
            if (_initialized) return;
            if (!db.Database.IsSqlServer()) { _initialized = true; return; }

            await db.Database.ExecuteSqlRawAsync("""
                IF OBJECT_ID(N'dbo.Friendships', N'U') IS NULL
                BEGIN
                    CREATE TABLE dbo.Friendships (
                        Id uniqueidentifier NOT NULL PRIMARY KEY,
                        RequesterId nvarchar(450) NOT NULL REFERENCES dbo.AspNetUsers(Id) ON DELETE CASCADE,
                        ReceiverId nvarchar(450) NOT NULL REFERENCES dbo.AspNetUsers(Id) ON DELETE NO ACTION,
                        Status nvarchar(20) NOT NULL DEFAULT 'Pending',
                        CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
                        UpdatedAt datetime2 NULL
                    );
                    CREATE UNIQUE INDEX IX_Friendships_Pair ON dbo.Friendships(RequesterId, ReceiverId);
                    CREATE INDEX IX_Friendships_ReceiverId ON dbo.Friendships(ReceiverId);
                    CREATE INDEX IX_Friendships_Status ON dbo.Friendships(Status);
                END

                IF OBJECT_ID(N'dbo.ChallengerDuels', N'U') IS NULL
                BEGIN
                    CREATE TABLE dbo.ChallengerDuels (
                        Id uniqueidentifier NOT NULL PRIMARY KEY,
                        ChallengeId nvarchar(64) NOT NULL,
                        ChallengeTitle nvarchar(120) NOT NULL,
                        ChallengeEmoji nvarchar(20) NOT NULL DEFAULT '🔥',
                        CreatorId nvarchar(450) NOT NULL REFERENCES dbo.AspNetUsers(Id) ON DELETE CASCADE,
                        OpponentId nvarchar(450) NOT NULL REFERENCES dbo.AspNetUsers(Id) ON DELETE NO ACTION,
                        Status nvarchar(20) NOT NULL DEFAULT 'Pending',
                        CreatorProgress int NOT NULL DEFAULT 0,
                        OpponentProgress int NOT NULL DEFAULT 0,
                        TargetValue int NOT NULL DEFAULT 10,
                        Unit nvarchar(50) NOT NULL DEFAULT 'buoi',
                        WinnerId nvarchar(450) NULL,
                        Notes nvarchar(500) NOT NULL DEFAULT '',
                        CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
                        CompletedAt datetime2 NULL
                    );
                    CREATE INDEX IX_ChallengerDuels_CreatorId ON dbo.ChallengerDuels(CreatorId);
                    CREATE INDEX IX_ChallengerDuels_OpponentId ON dbo.ChallengerDuels(OpponentId);
                    CREATE INDEX IX_ChallengerDuels_Status ON dbo.ChallengerDuels(Status);
                END
                """);
            _initialized = true;
        }
        catch { }
        finally { _semaphore.Release(); }
    }

    public static async Task<List<FriendUserDto>> GetFriendsAsync(ApplicationDbContext db, string userId)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        var sql = """
            SELECT 
                u.Id, u.FullName, u.Email, u.TrainingLevel, u.Goal, f.Id AS FriendshipId,
                (SELECT COUNT(*) FROM dbo.UserChallenges uc WHERE uc.UserId = u.Id AND uc.IsCompleted = 1) AS CompletedChallengesCount,
                (SELECT COUNT(*) FROM dbo.ChallengerDuels cd WHERE cd.WinnerId = u.Id AND cd.Status = 'Completed') AS WonDuelsCount,
                (SELECT COUNT(*) FROM dbo.ChallengerDuels cd WHERE (cd.CreatorId = u.Id OR cd.OpponentId = u.Id) AND cd.Status = 'Active') AS ActiveDuelsCount
            FROM dbo.Friendships f
            INNER JOIN dbo.AspNetUsers u 
                ON (f.RequesterId = @UserId AND f.ReceiverId = u.Id) 
                OR (f.ReceiverId = @UserId AND f.RequesterId = u.Id)
            WHERE f.Status = 'Accepted' AND u.Id <> @UserId
            ORDER BY u.FullName ASC;
            """;

        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        var p = cmd.CreateParameter(); p.ParameterName = "@UserId"; p.Value = userId; cmd.Parameters.Add(p);

        var list = new List<FriendUserDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new FriendUserDto
            {
                Id = reader.GetString(0),
                FullName = reader.IsDBNull(1) ? "" : reader.GetString(1),
                Email = reader.IsDBNull(2) ? "" : reader.GetString(2),
                TrainingLevel = reader.IsDBNull(3) ? null : reader.GetString(3),
                Goal = reader.IsDBNull(4) ? null : reader.GetString(4),
                FriendshipId = reader.GetGuid(5),
                CompletedChallengesCount = reader.GetInt32(6),
                WonDuelsCount = reader.GetInt32(7),
                ActiveDuelsCount = reader.GetInt32(8),
                Status = "Friend"
            });
        }
        return list;
    }

    public static async Task<List<FriendRequestDto>> GetFriendRequestsAsync(ApplicationDbContext db, string userId)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        var sql = """
            SELECT 
                f.Id, u.Id AS UserId, u.FullName, u.Email, u.TrainingLevel,
                CASE WHEN f.ReceiverId = @UserId THEN 1 ELSE 0 END AS IsIncoming,
                f.CreatedAt
            FROM dbo.Friendships f
            INNER JOIN dbo.AspNetUsers u 
                ON (f.ReceiverId = @UserId AND f.RequesterId = u.Id)
                OR (f.RequesterId = @UserId AND f.ReceiverId = u.Id)
            WHERE f.Status = 'Pending' AND (f.RequesterId = @UserId OR f.ReceiverId = @UserId)
            ORDER BY f.CreatedAt DESC;
            """;

        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        var p = cmd.CreateParameter(); p.ParameterName = "@UserId"; p.Value = userId; cmd.Parameters.Add(p);

        var list = new List<FriendRequestDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new FriendRequestDto
            {
                Id = reader.GetGuid(0),
                UserId = reader.GetString(1),
                FullName = reader.IsDBNull(2) ? "" : reader.GetString(2),
                Email = reader.IsDBNull(3) ? "" : reader.GetString(3),
                TrainingLevel = reader.IsDBNull(4) ? null : reader.GetString(4),
                IsIncoming = reader.GetInt32(5) == 1,
                CreatedAt = reader.GetDateTime(6)
            });
        }
        return list;
    }

    public static async Task<List<FriendUserDto>> SearchUsersAsync(ApplicationDbContext db, string currentUserId, string query)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        var sql = """
            SELECT TOP 20
                u.Id, u.FullName, u.Email, u.TrainingLevel, u.Goal, f.Id AS FriendshipId,
                f.Status AS FriendshipStatus, f.RequesterId,
                (SELECT COUNT(*) FROM dbo.UserChallenges uc WHERE uc.UserId = u.Id AND uc.IsCompleted = 1) AS CompletedChallengesCount,
                (SELECT COUNT(*) FROM dbo.ChallengerDuels cd WHERE cd.WinnerId = u.Id AND cd.Status = 'Completed') AS WonDuelsCount
            FROM dbo.AspNetUsers u
            LEFT JOIN dbo.Friendships f 
                ON ((f.RequesterId = @CurrentUserId AND f.ReceiverId = u.Id) 
                    OR (f.ReceiverId = @CurrentUserId AND f.RequesterId = u.Id))
            WHERE u.Id <> @CurrentUserId
              AND (u.FullName LIKE @Pattern OR u.Email LIKE @Pattern OR u.UserName LIKE @Pattern)
            ORDER BY u.FullName ASC;
            """;

        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        var p1 = cmd.CreateParameter(); p1.ParameterName = "@CurrentUserId"; p1.Value = currentUserId; cmd.Parameters.Add(p1);
        var p2 = cmd.CreateParameter(); p2.ParameterName = "@Pattern"; p2.Value = $"%{query.Trim()}%"; cmd.Parameters.Add(p2);

        var list = new List<FriendUserDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var fId = reader.IsDBNull(5) ? (Guid?)null : reader.GetGuid(5);
            var fStatus = reader.IsDBNull(6) ? null : reader.GetString(6);
            var fReqId = reader.IsDBNull(7) ? null : reader.GetString(7);

            var status = "None";
            if (fStatus == "Accepted") status = "Friend";
            else if (fStatus == "Pending")
            {
                status = fReqId == currentUserId ? "PendingOutgoing" : "PendingIncoming";
            }

            list.Add(new FriendUserDto
            {
                Id = reader.GetString(0),
                FullName = reader.IsDBNull(1) ? "" : reader.GetString(1),
                Email = reader.IsDBNull(2) ? "" : reader.GetString(2),
                TrainingLevel = reader.IsDBNull(3) ? null : reader.GetString(3),
                Goal = reader.IsDBNull(4) ? null : reader.GetString(4),
                FriendshipId = fId,
                CompletedChallengesCount = reader.GetInt32(8),
                WonDuelsCount = reader.GetInt32(9),
                Status = status
            });
        }
        return list;
    }

    public static async Task<(bool ok, string message)> SendFriendRequestAsync(ApplicationDbContext db, string currentUserId, string targetUserId)
    {
        await EnsureSchemaAsync(db);
        if (currentUserId == targetUserId) return (false, "Không thể kết bạn với chính mình.");
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        using (var checkCmd = conn.CreateCommand())
        {
            checkCmd.CommandText = """
                SELECT RequesterId, Status FROM dbo.Friendships 
                WHERE (RequesterId = @U1 AND ReceiverId = @U2) OR (RequesterId = @U2 AND ReceiverId = @U1)
                """;
            var p1 = checkCmd.CreateParameter(); p1.ParameterName = "@U1"; p1.Value = currentUserId; checkCmd.Parameters.Add(p1);
            var p2 = checkCmd.CreateParameter(); p2.ParameterName = "@U2"; p2.Value = targetUserId; checkCmd.Parameters.Add(p2);
            using var reader = await checkCmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                var reqId = reader.GetString(0);
                var status = reader.GetString(1);
                if (status == "Accepted") return (false, "Hai bạn đã là bạn bè rồi.");
                if (status == "Pending")
                {
                    return reqId == currentUserId
                        ? (false, "Bạn đã gửi lời mời kết bạn trước đó.")
                        : (false, "Người này đã gửi lời mời kết bạn cho bạn. Hãy chấp nhận.");
                }
            }
        }

        using (var insertCmd = conn.CreateCommand())
        {
            insertCmd.CommandText = "INSERT INTO dbo.Friendships (Id, RequesterId, ReceiverId, Status, CreatedAt) VALUES (@Id, @R1, @R2, 'Pending', SYSUTCDATETIME());";
            var pId = insertCmd.CreateParameter(); pId.ParameterName = "@Id"; pId.Value = Guid.NewGuid(); insertCmd.Parameters.Add(pId);
            var pR1 = insertCmd.CreateParameter(); pR1.ParameterName = "@R1"; pR1.Value = currentUserId; insertCmd.Parameters.Add(pR1);
            var pR2 = insertCmd.CreateParameter(); pR2.ParameterName = "@R2"; pR2.Value = targetUserId; insertCmd.Parameters.Add(pR2);
            await insertCmd.ExecuteNonQueryAsync();
        }
        return (true, "Đã gửi lời mời kết bạn!");
    }

    public static async Task<(bool ok, string message)> AcceptFriendRequestAsync(ApplicationDbContext db, string currentUserId, Guid requestId)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE dbo.Friendships SET Status = 'Accepted', UpdatedAt = SYSUTCDATETIME() WHERE Id = @Id AND ReceiverId = @U AND Status = 'Pending';";
        var p1 = cmd.CreateParameter(); p1.ParameterName = "@Id"; p1.Value = requestId; cmd.Parameters.Add(p1);
        var p2 = cmd.CreateParameter(); p2.ParameterName = "@U"; p2.Value = currentUserId; cmd.Parameters.Add(p2);

        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0 ? (true, "Đã đồng ý kết bạn!") : (false, "Không tìm thấy lời mời hợp lệ.");
    }

    public static async Task<(bool ok, string message)> DeclineFriendRequestAsync(ApplicationDbContext db, string currentUserId, Guid requestId)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM dbo.Friendships WHERE Id = @Id AND (ReceiverId = @U OR RequesterId = @U);";
        var p1 = cmd.CreateParameter(); p1.ParameterName = "@Id"; p1.Value = requestId; cmd.Parameters.Add(p1);
        var p2 = cmd.CreateParameter(); p2.ParameterName = "@U"; p2.Value = currentUserId; cmd.Parameters.Add(p2);

        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0 ? (true, "Đã từ chối lời mời.") : (false, "Không tìm thấy lời mời.");
    }

    public static async Task<(bool ok, string message)> UnfriendAsync(ApplicationDbContext db, string currentUserId, string friendUserId)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM dbo.Friendships WHERE (RequesterId = @U AND ReceiverId = @F) OR (RequesterId = @F AND ReceiverId = @U);";
        var p1 = cmd.CreateParameter(); p1.ParameterName = "@U"; p1.Value = currentUserId; cmd.Parameters.Add(p1);
        var p2 = cmd.CreateParameter(); p2.ParameterName = "@F"; p2.Value = friendUserId; cmd.Parameters.Add(p2);

        await cmd.ExecuteNonQueryAsync();
        return (true, "Đã hủy kết bạn.");
    }

    public static async Task<List<DuelItemDto>> GetDuelsAsync(ApplicationDbContext db, string userId)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        var sql = """
            SELECT 
                d.Id, d.ChallengeId, d.ChallengeTitle, d.ChallengeEmoji, d.Status,
                d.TargetValue, d.Unit, d.Notes, d.CreatedAt, d.CompletedAt,
                d.CreatorId, uc.FullName AS CreatorName, d.CreatorProgress,
                d.OpponentId, uo.FullName AS OpponentName, d.OpponentProgress,
                d.WinnerId, uw.FullName AS WinnerName
            FROM dbo.ChallengerDuels d
            INNER JOIN dbo.AspNetUsers uc ON d.CreatorId = uc.Id
            INNER JOIN dbo.AspNetUsers uo ON d.OpponentId = uo.Id
            LEFT JOIN dbo.AspNetUsers uw ON d.WinnerId = uw.Id
            WHERE d.CreatorId = @UserId OR d.OpponentId = @UserId
            ORDER BY CASE WHEN d.Status = 'Pending' THEN 1 WHEN d.Status = 'Active' THEN 2 ELSE 3 END, d.CreatedAt DESC;
            """;

        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        var p = cmd.CreateParameter(); p.ParameterName = "@UserId"; p.Value = userId; cmd.Parameters.Add(p);

        var list = new List<DuelItemDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var creatorId = reader.GetString(10);
            var isCreator = creatorId == userId;
            var creatorProgress = reader.GetInt32(12);
            var opponentProgress = reader.GetInt32(15);
            var winnerId = reader.IsDBNull(16) ? null : reader.GetString(16);

            list.Add(new DuelItemDto
            {
                Id = reader.GetGuid(0),
                ChallengeId = reader.GetString(1),
                ChallengeTitle = reader.GetString(2),
                ChallengeEmoji = reader.GetString(3),
                Status = reader.GetString(4),
                TargetValue = reader.GetInt32(5),
                Unit = reader.GetString(6),
                Notes = reader.IsDBNull(7) ? "" : reader.GetString(7),
                CreatedAt = reader.GetDateTime(8),
                CompletedAt = reader.IsDBNull(9) ? null : reader.GetDateTime(9),
                CreatorId = creatorId,
                CreatorName = reader.IsDBNull(11) ? "Challenger" : reader.GetString(11),
                CreatorProgress = creatorProgress,
                OpponentId = reader.GetString(13),
                OpponentName = reader.IsDBNull(14) ? "Challenger" : reader.GetString(14),
                OpponentProgress = opponentProgress,
                WinnerId = winnerId,
                WinnerName = reader.IsDBNull(17) ? null : reader.GetString(17),
                IsCreator = isCreator,
                MyProgress = isCreator ? creatorProgress : opponentProgress,
                OpponentProgressForMe = isCreator ? opponentProgress : creatorProgress,
                IsMyTurn = reader.GetString(4) == "Active",
                IsWonByMe = winnerId == userId
            });
        }
        return list;
    }

    public static async Task<(bool ok, string message, Guid? duelId)> CreateDuelAsync(
        ApplicationDbContext db, string creatorId, string opponentId, string challengeId, int targetValue, string notes)
    {
        await EnsureSchemaAsync(db);
        if (creatorId == opponentId) return (false, "Không thể thách đấu với chính mình.", null);

        var def = ChallengeCatalog.Get(challengeId);
        if (def == null) return (false, "Thử thách không hợp lệ.", null);

        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        var target = targetValue > 0 ? targetValue : def.Steps.Sum(s => s.TargetValue);
        var unit = def.Steps.FirstOrDefault()?.Unit ?? "lần";
        var duelId = Guid.NewGuid();

        using var insertCmd = conn.CreateCommand();
        insertCmd.CommandText = """
            INSERT INTO dbo.ChallengerDuels 
            (Id, ChallengeId, ChallengeTitle, ChallengeEmoji, CreatorId, OpponentId, Status, CreatorProgress, OpponentProgress, TargetValue, Unit, Notes, CreatedAt)
            VALUES 
            (@Id, @ChallengeId, @ChallengeTitle, @ChallengeEmoji, @CreatorId, @OpponentId, 'Pending', 0, 0, @TargetValue, @Unit, @Notes, SYSUTCDATETIME());
            """;
        var p1 = insertCmd.CreateParameter(); p1.ParameterName = "@Id"; p1.Value = duelId; insertCmd.Parameters.Add(p1);
        var p2 = insertCmd.CreateParameter(); p2.ParameterName = "@ChallengeId"; p2.Value = challengeId; insertCmd.Parameters.Add(p2);
        var p3 = insertCmd.CreateParameter(); p3.ParameterName = "@ChallengeTitle"; p3.Value = def.Title; insertCmd.Parameters.Add(p3);
        var p4 = insertCmd.CreateParameter(); p4.ParameterName = "@ChallengeEmoji"; p4.Value = def.Emoji; insertCmd.Parameters.Add(p4);
        var p5 = insertCmd.CreateParameter(); p5.ParameterName = "@CreatorId"; p5.Value = creatorId; insertCmd.Parameters.Add(p5);
        var p6 = insertCmd.CreateParameter(); p6.ParameterName = "@OpponentId"; p6.Value = opponentId; insertCmd.Parameters.Add(p6);
        var p7 = insertCmd.CreateParameter(); p7.ParameterName = "@TargetValue"; p7.Value = target; insertCmd.Parameters.Add(p7);
        var p8 = insertCmd.CreateParameter(); p8.ParameterName = "@Unit"; p8.Value = unit; insertCmd.Parameters.Add(p8);
        var p9 = insertCmd.CreateParameter(); p9.ParameterName = "@Notes"; p9.Value = notes ?? ""; insertCmd.Parameters.Add(p9);

        await insertCmd.ExecuteNonQueryAsync();
        return (true, $"Đã gửi lời thách đấu \"{def.Title}\"!", duelId);
    }

    public static async Task<(bool ok, string message)> AcceptDuelAsync(ApplicationDbContext db, string currentUserId, Guid duelId)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE dbo.ChallengerDuels SET Status = 'Active' WHERE Id = @Id AND OpponentId = @U AND Status = 'Pending';";
        var p1 = cmd.CreateParameter(); p1.ParameterName = "@Id"; p1.Value = duelId; cmd.Parameters.Add(p1);
        var p2 = cmd.CreateParameter(); p2.ParameterName = "@U"; p2.Value = currentUserId; cmd.Parameters.Add(p2);

        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0 ? (true, "Đã chấp nhận thách đấu!") : (false, "Không tìm thấy lời thách đấu.");
    }

    public static async Task<(bool ok, string message)> DeclineDuelAsync(ApplicationDbContext db, string currentUserId, Guid duelId)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE dbo.ChallengerDuels SET Status = 'Declined' WHERE Id = @Id AND (OpponentId = @U OR CreatorId = @U) AND Status = 'Pending';";
        var p1 = cmd.CreateParameter(); p1.ParameterName = "@Id"; p1.Value = duelId; cmd.Parameters.Add(p1);
        var p2 = cmd.CreateParameter(); p2.ParameterName = "@U"; p2.Value = currentUserId; cmd.Parameters.Add(p2);

        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0 ? (true, "Đã từ chối thách đấu.") : (false, "Không thể từ chối trận đấu.");
    }

    public static async Task<(bool ok, string message)> UpdateDuelProgressAsync(ApplicationDbContext db, string currentUserId, Guid duelId, int amount)
    {
        await EnsureSchemaAsync(db);
        if (amount <= 0) return (false, "Số lượng phải lớn hơn 0.");

        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        using var checkCmd = conn.CreateCommand();
        checkCmd.CommandText = "SELECT CreatorId, OpponentId, Status, CreatorProgress, OpponentProgress, TargetValue FROM dbo.ChallengerDuels WHERE Id = @Id;";
        var pId = checkCmd.CreateParameter(); pId.ParameterName = "@Id"; pId.Value = duelId; checkCmd.Parameters.Add(pId);

        using var reader = await checkCmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return (false, "Không tìm thấy trận đấu.");

        var creatorId = reader.GetString(0);
        var opponentId = reader.GetString(1);
        var status = reader.GetString(2);
        var creatorProgress = reader.GetInt32(3);
        var opponentProgress = reader.GetInt32(4);
        var targetValue = reader.GetInt32(5);
        reader.Close();

        if (status != "Active") return (false, "Trận đấu không ở trạng thái thi đua.");
        if (creatorId != currentUserId && opponentId != currentUserId) return (false, "Bạn không tham gia trận đấu này.");

        var isCreator = creatorId == currentUserId;
        var newCreatorProgress = isCreator ? creatorProgress + amount : creatorProgress;
        var newOpponentProgress = !isCreator ? opponentProgress + amount : opponentProgress;
        var myNewProgress = isCreator ? newCreatorProgress : newOpponentProgress;
        var hasWon = myNewProgress >= targetValue;

        using var updateCmd = conn.CreateCommand();
        if (hasWon)
        {
            updateCmd.CommandText = "UPDATE dbo.ChallengerDuels SET CreatorProgress = @CP, OpponentProgress = @OP, Status = 'Completed', WinnerId = @WinnerId, CompletedAt = SYSUTCDATETIME() WHERE Id = @Id;";
            var pW = updateCmd.CreateParameter(); pW.ParameterName = "@WinnerId"; pW.Value = currentUserId; updateCmd.Parameters.Add(pW);
        }
        else
        {
            updateCmd.CommandText = "UPDATE dbo.ChallengerDuels SET CreatorProgress = @CP, OpponentProgress = @OP WHERE Id = @Id;";
        }

        var pU1 = updateCmd.CreateParameter(); pU1.ParameterName = "@Id"; pU1.Value = duelId; updateCmd.Parameters.Add(pU1);
        var pU2 = updateCmd.CreateParameter(); pU2.ParameterName = "@CP"; pU2.Value = newCreatorProgress; updateCmd.Parameters.Add(pU2);
        var pU3 = updateCmd.CreateParameter(); pU3.ParameterName = "@OP"; pU3.Value = newOpponentProgress; updateCmd.Parameters.Add(pU3);

        await updateCmd.ExecuteNonQueryAsync();
        return hasWon
            ? (true, $"🎉 CHÚC MỪNG! Bạn đã cán đích {targetValue} và CHIẾN THẮNG!")
            : (true, $"Đã cập nhật tiến độ! Bạn đạt {myNewProgress}/{targetValue}.");
    }

    public static async Task<List<LeaderboardItemDto>> GetLeaderboardAsync(ApplicationDbContext db, string currentUserId, bool friendsOnly)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        string sql = friendsOnly
            ? """
                SELECT u.Id, u.FullName, u.TrainingLevel, ISNULL(c.CompletedCount, 0) AS CompletedChallenges, ISNULL(d.WonCount, 0) AS WonDuels, (ISNULL(c.CompletedCount, 0) * 100 + ISNULL(d.WonCount, 0) * 50) AS Score
                FROM dbo.AspNetUsers u
                LEFT JOIN (SELECT UserId, COUNT(*) AS CompletedCount FROM dbo.UserChallenges WHERE IsCompleted = 1 GROUP BY UserId) c ON u.Id = c.UserId
                LEFT JOIN (SELECT WinnerId, COUNT(*) AS WonCount FROM dbo.ChallengerDuels WHERE Status = 'Completed' GROUP BY WinnerId) d ON u.Id = d.WinnerId
                WHERE u.Id = @UserId OR u.Id IN (
                    SELECT CASE WHEN RequesterId = @UserId THEN ReceiverId ELSE RequesterId END
                    FROM dbo.Friendships WHERE (RequesterId = @UserId OR ReceiverId = @UserId) AND Status = 'Accepted'
                )
                ORDER BY Score DESC, WonDuels DESC, CompletedChallenges DESC;
                """
            : """
                SELECT TOP 50 u.Id, u.FullName, u.TrainingLevel, ISNULL(c.CompletedCount, 0) AS CompletedChallenges, ISNULL(d.WonCount, 0) AS WonDuels, (ISNULL(c.CompletedCount, 0) * 100 + ISNULL(d.WonCount, 0) * 50) AS Score
                FROM dbo.AspNetUsers u
                LEFT JOIN (SELECT UserId, COUNT(*) AS CompletedCount FROM dbo.UserChallenges WHERE IsCompleted = 1 GROUP BY UserId) c ON u.Id = c.UserId
                LEFT JOIN (SELECT WinnerId, COUNT(*) AS WonCount FROM dbo.ChallengerDuels WHERE Status = 'Completed' GROUP BY WinnerId) d ON u.Id = d.WinnerId
                ORDER BY Score DESC, WonDuels DESC, CompletedChallenges DESC;
                """;

        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        var p = cmd.CreateParameter(); p.ParameterName = "@UserId"; p.Value = currentUserId; cmd.Parameters.Add(p);

        var list = new List<LeaderboardItemDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        var rank = 1;
        while (await reader.ReadAsync())
        {
            var uId = reader.GetString(0);
            list.Add(new LeaderboardItemDto
            {
                Rank = rank++,
                UserId = uId,
                FullName = reader.IsDBNull(1) ? "Challenger" : reader.GetString(1),
                TrainingLevel = reader.IsDBNull(2) ? "Học viên" : reader.GetString(2),
                CompletedChallenges = reader.GetInt32(3),
                WonDuels = reader.GetInt32(4),
                Score = reader.GetInt32(5),
                IsCurrentUser = uId == currentUserId,
                IsFriend = false
            });
        }
        return list;
    }

    public static int GetPointsForDifficulty(string difficulty) => (difficulty ?? "").ToLowerInvariant() switch
    {
        "easy" => 10,
        "medium" => 25,
        "hard" => 50,
        _ => 20
    };

    public static async Task<List<MedalDto>> GetMyMedalsAsync(ApplicationDbContext db, string userId)
    {
        await EnsureSchemaAsync(db);
        var userChallenges = await db.UserChallenges
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .ToListAsync();

        var result = new List<MedalDto>();
        foreach (var def in ChallengeCatalog.Definitions)
        {
            var uc = userChallenges.FirstOrDefault(x => x.ChallengeId == def.Id);
            var earned = uc?.IsCompleted == true;
            result.Add(new MedalDto
            {
                ChallengeId = def.Id,
                ChallengeTitle = def.Title,
                MedalTitle = def.MedalTitle,
                MedalDescription = def.MedalDescription,
                Emoji = def.Emoji,
                Difficulty = def.Difficulty,
                Points = GetPointsForDifficulty(def.Difficulty),
                Earned = earned,
                EarnedAt = earned ? uc?.CompletedAt : null,
                CurrentProgress = uc?.CurrentProgress ?? 0,
                TotalSteps = def.Steps.Count,
                CompletedSteps = uc?.CurrentStepIndex ?? 0
            });
        }
        return result;
    }

    public static async Task<(bool ok, string message, MedalCompareDto? data)> CompareMedalsAsync(
        ApplicationDbContext db, string currentUserId, string friendId)
    {
        await EnsureSchemaAsync(db);

        if (currentUserId != friendId)
        {
            var conn = db.Database.GetDbConnection();
            if (conn.State != ConnectionState.Open) await conn.OpenAsync();

            using var checkCmd = conn.CreateCommand();
            checkCmd.CommandText = """
                SELECT COUNT(*) FROM dbo.Friendships 
                WHERE Status = 'Accepted' 
                  AND ((RequesterId = @U1 AND ReceiverId = @U2) OR (RequesterId = @U2 AND ReceiverId = @U1));
                """;
            var p1 = checkCmd.CreateParameter(); p1.ParameterName = "@U1"; p1.Value = currentUserId; checkCmd.Parameters.Add(p1);
            var p2 = checkCmd.CreateParameter(); p2.ParameterName = "@U2"; p2.Value = friendId; checkCmd.Parameters.Add(p2);

            var count = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());
            if (count == 0)
            {
                return (false, "Người dùng này chưa kết bạn với bạn.", null);
            }
        }

        var myUser = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == currentUserId);
        var friendUser = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == friendId);

        if (friendUser == null)
        {
            return (false, "Không tìm thấy thông tin bạn bè.", null);
        }

        var myChallenges = await db.UserChallenges.AsNoTracking()
            .Where(x => x.UserId == currentUserId && x.IsCompleted)
            .ToListAsync();

        var friendChallenges = await db.UserChallenges.AsNoTracking()
            .Where(x => x.UserId == friendId && x.IsCompleted)
            .ToListAsync();

        var items = new List<MedalCompareItemDto>();
        int myPoints = 0;
        int friendPoints = 0;
        int myMedals = 0;
        int friendMedals = 0;

        foreach (var def in ChallengeCatalog.Definitions)
        {
            var myUc = myChallenges.FirstOrDefault(x => x.ChallengeId == def.Id);
            var friendUc = friendChallenges.FirstOrDefault(x => x.ChallengeId == def.Id);

            var myEarned = myUc != null;
            var friendEarned = friendUc != null;
            var pts = GetPointsForDifficulty(def.Difficulty);

            if (myEarned)
            {
                myPoints += pts;
                myMedals++;
            }
            if (friendEarned)
            {
                friendPoints += pts;
                friendMedals++;
            }

            items.Add(new MedalCompareItemDto
            {
                ChallengeId = def.Id,
                ChallengeTitle = def.Title,
                MedalTitle = def.MedalTitle,
                MedalDescription = def.MedalDescription,
                Emoji = def.Emoji,
                Difficulty = def.Difficulty,
                Points = pts,
                MyEarned = myEarned,
                MyEarnedAt = myUc?.CompletedAt,
                FriendEarned = friendEarned,
                FriendEarnedAt = friendUc?.CompletedAt
            });
        }

        var dto = new MedalCompareDto
        {
            MyUserId = currentUserId,
            MyName = myUser?.FullName ?? "Tôi",
            MyTotalPoints = myPoints,
            MyMedalsCount = myMedals,
            FriendUserId = friendId,
            FriendName = friendUser.FullName ?? "Bạn bè",
            FriendTotalPoints = friendPoints,
            FriendMedalsCount = friendMedals,
            TotalAvailableMedals = ChallengeCatalog.Definitions.Count,
            Items = items
        };

        return (true, "OK", dto);
    }

    public static async Task<List<MedalLeaderboardItemDto>> GetMedalLeaderboardAsync(
        ApplicationDbContext db, string currentUserId, bool friendsOnly)
    {
        await EnsureSchemaAsync(db);
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open) await conn.OpenAsync();

        string usersSql = friendsOnly
            ? """
                SELECT u.Id, u.FullName, u.TrainingLevel
                FROM dbo.AspNetUsers u
                WHERE u.Id = @UserId OR u.Id IN (
                    SELECT CASE WHEN RequesterId = @UserId THEN ReceiverId ELSE RequesterId END
                    FROM dbo.Friendships WHERE (RequesterId = @UserId OR ReceiverId = @UserId) AND Status = 'Accepted'
                );
                """
            : """
                SELECT TOP 50 u.Id, u.FullName, u.TrainingLevel
                FROM dbo.AspNetUsers u;
                """;

        using var cmd = conn.CreateCommand();
        cmd.CommandText = usersSql;
        var p = cmd.CreateParameter(); p.ParameterName = "@UserId"; p.Value = currentUserId; cmd.Parameters.Add(p);

        var users = new List<(string Id, string Name, string? Level)>();
        using (var reader = await cmd.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                users.Add((
                    reader.GetString(0),
                    reader.IsDBNull(1) ? "Challenger" : reader.GetString(1),
                    reader.IsDBNull(2) ? "Học viên" : reader.GetString(2)
                ));
            }
        }

        var userIds = users.Select(u => u.Id).ToList();
        var completedChallenges = await db.UserChallenges.AsNoTracking()
            .Where(x => userIds.Contains(x.UserId) && x.IsCompleted)
            .Select(x => new { x.UserId, x.ChallengeId })
            .ToListAsync();

        var pointsMap = ChallengeCatalog.Definitions.ToDictionary(
            d => d.Id,
            d => GetPointsForDifficulty(d.Difficulty)
        );

        var list = new List<MedalLeaderboardItemDto>();
        foreach (var u in users)
        {
            var uChallenges = completedChallenges.Where(c => c.UserId == u.Id).ToList();
            var medalsCount = uChallenges.Count;
            var totalPoints = uChallenges.Sum(c => pointsMap.TryGetValue(c.ChallengeId, out var pts) ? pts : 10);

            list.Add(new MedalLeaderboardItemDto
            {
                UserId = u.Id,
                FullName = u.Name,
                TrainingLevel = u.Level,
                MedalsCount = medalsCount,
                TotalPoints = totalPoints,
                IsCurrentUser = u.Id == currentUserId,
                IsFriend = false
            });
        }

        list = list
            .OrderByDescending(x => x.TotalPoints)
            .ThenByDescending(x => x.MedalsCount)
            .ThenBy(x => x.FullName)
            .ToList();

        for (int i = 0; i < list.Count; i++)
        {
            list[i].Rank = i + 1;
        }

        return list;
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. API CONTROLLERS
// ═════════════════════════════════════════════════════════════════════════════

[Authorize]
[ApiController]
[Route("api/friends")]
public class FriendsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public FriendsController(ApplicationDbContext db) => _db = db;

    private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId") ?? string.Empty;

    [HttpGet]
    public async Task<IActionResult> GetFriends() => Ok(await FriendsCompetitionDataHelper.GetFriendsAsync(_db, GetUserId()));

    [HttpGet("requests")]
    public async Task<IActionResult> GetRequests() => Ok(await FriendsCompetitionDataHelper.GetFriendRequestsAsync(_db, GetUserId()));

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string? q)
    {
        if (string.IsNullOrWhiteSpace(q)) return Ok(new List<FriendUserDto>());
        return Ok(await FriendsCompetitionDataHelper.SearchUsersAsync(_db, GetUserId(), q));
    }

    [HttpPost("request")]
    public async Task<IActionResult> SendRequest([FromBody] SendFriendRequestInput input)
    {
        if (string.IsNullOrWhiteSpace(input.TargetUserId)) return BadRequest(new { message = "Vui lòng chọn người dùng." });
        var (ok, message) = await FriendsCompetitionDataHelper.SendFriendRequestAsync(_db, GetUserId(), input.TargetUserId);
        return ok ? Ok(new { message }) : BadRequest(new { message });
    }

    [HttpPost("requests/{id:guid}/accept")]
    public async Task<IActionResult> AcceptRequest(Guid id)
    {
        var (ok, message) = await FriendsCompetitionDataHelper.AcceptFriendRequestAsync(_db, GetUserId(), id);
        return ok ? Ok(new { message }) : BadRequest(new { message });
    }

    [HttpPost("requests/{id:guid}/decline")]
    public async Task<IActionResult> DeclineRequest(Guid id)
    {
        var (ok, message) = await FriendsCompetitionDataHelper.DeclineFriendRequestAsync(_db, GetUserId(), id);
        return ok ? Ok(new { message }) : BadRequest(new { message });
    }

    [HttpDelete("{friendId}")]
    public async Task<IActionResult> Unfriend(string friendId)
    {
        var (ok, message) = await FriendsCompetitionDataHelper.UnfriendAsync(_db, GetUserId(), friendId);
        return ok ? Ok(new { message }) : BadRequest(new { message });
    }
}

[Authorize]
[ApiController]
[Route("api/challengerduels")]
public class ChallengerDuelsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public ChallengerDuelsController(ApplicationDbContext db) => _db = db;

    private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId") ?? string.Empty;

    [HttpGet]
    public async Task<IActionResult> GetDuels() => Ok(await FriendsCompetitionDataHelper.GetDuelsAsync(_db, GetUserId()));

    [HttpGet("leaderboard")]
    public async Task<IActionResult> GetLeaderboard([FromQuery] string? scope)
    {
        var friendsOnly = string.Equals(scope, "friends", StringComparison.OrdinalIgnoreCase);
        return Ok(await FriendsCompetitionDataHelper.GetLeaderboardAsync(_db, GetUserId(), friendsOnly));
    }

    [HttpPost]
    public async Task<IActionResult> CreateDuel([FromBody] CreateDuelInput input)
    {
        if (string.IsNullOrWhiteSpace(input.OpponentId)) return BadRequest(new { message = "Vui lòng chọn đối thủ." });
        if (string.IsNullOrWhiteSpace(input.ChallengeId)) return BadRequest(new { message = "Vui lòng chọn thử thách." });

        var (ok, message, duelId) = await FriendsCompetitionDataHelper.CreateDuelAsync(
            _db, GetUserId(), input.OpponentId, input.ChallengeId, input.TargetValue, input.Notes ?? "");
        return ok ? Ok(new { message, duelId }) : BadRequest(new { message });
    }

    [HttpPost("{id:guid}/accept")]
    public async Task<IActionResult> AcceptDuel(Guid id)
    {
        var (ok, message) = await FriendsCompetitionDataHelper.AcceptDuelAsync(_db, GetUserId(), id);
        return ok ? Ok(new { message }) : BadRequest(new { message });
    }

    [HttpPost("{id:guid}/decline")]
    public async Task<IActionResult> DeclineDuel(Guid id)
    {
        var (ok, message) = await FriendsCompetitionDataHelper.DeclineDuelAsync(_db, GetUserId(), id);
        return ok ? Ok(new { message }) : BadRequest(new { message });
    }

    [HttpPost("{id:guid}/progress")]
    public async Task<IActionResult> UpdateProgress(Guid id, [FromBody] UpdateDuelProgressInput input)
    {
        if (input.Amount <= 0) return BadRequest(new { message = "Số lượng phải lớn hơn 0." });
        var (ok, message) = await FriendsCompetitionDataHelper.UpdateDuelProgressAsync(_db, GetUserId(), id, input.Amount);
        return ok ? Ok(new { message }) : BadRequest(new { message });
    }
}

[Authorize]
[ApiController]
[Route("api/medals")]
public class MedalsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public MedalsController(ApplicationDbContext db) => _db = db;

    private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId") ?? string.Empty;

    [HttpGet("my")]
    public async Task<IActionResult> GetMyMedals()
    {
        var medals = await FriendsCompetitionDataHelper.GetMyMedalsAsync(_db, GetUserId());
        return Ok(medals);
    }

    [HttpGet("compare/{friendId}")]
    public async Task<IActionResult> CompareMedals(string friendId)
    {
        var (ok, message, data) = await FriendsCompetitionDataHelper.CompareMedalsAsync(_db, GetUserId(), friendId);
        return ok ? Ok(data) : BadRequest(new { message });
    }

    [HttpGet("leaderboard")]
    public async Task<IActionResult> GetMedalLeaderboard([FromQuery] string? scope)
    {
        var friendsOnly = string.Equals(scope, "friends", StringComparison.OrdinalIgnoreCase);
        var list = await FriendsCompetitionDataHelper.GetMedalLeaderboardAsync(_db, GetUserId(), friendsOnly);
        return Ok(list);
    }
}
