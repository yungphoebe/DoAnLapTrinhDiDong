using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AiGym.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddRunningRemindersAndActivityRoutes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Older installations create notifications at startup rather than
            // through EF migrations. Fresh databases receive the full schema
            // from NotificationSchema after migrations have completed.
            migrationBuilder.Sql("""
                IF OBJECT_ID(N'dbo.ReminderSettings', N'U') IS NOT NULL
                BEGIN
                  IF COL_LENGTH(N'dbo.ReminderSettings', N'RunningDays') IS NULL
                    ALTER TABLE dbo.ReminderSettings ADD RunningDays nvarchar(20) NOT NULL DEFAULT '1,2,3,4,5,6,7';
                  IF COL_LENGTH(N'dbo.ReminderSettings', N'RunningEnabled') IS NULL
                    ALTER TABLE dbo.ReminderSettings ADD RunningEnabled bit NOT NULL DEFAULT 0;
                  IF COL_LENGTH(N'dbo.ReminderSettings', N'RunningMinute') IS NULL
                    ALTER TABLE dbo.ReminderSettings ADD RunningMinute int NOT NULL DEFAULT 420;
                END
                """);

            migrationBuilder.AddColumn<string>(
                name: "RouteJson",
                table: "ActivitySessions",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RunningDays",
                table: "ReminderSettings");

            migrationBuilder.DropColumn(
                name: "RunningEnabled",
                table: "ReminderSettings");

            migrationBuilder.DropColumn(
                name: "RunningMinute",
                table: "ReminderSettings");

            migrationBuilder.DropColumn(
                name: "RouteJson",
                table: "ActivitySessions");
        }
    }
}
