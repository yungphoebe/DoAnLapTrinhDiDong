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
            migrationBuilder.AddColumn<string>(
                name: "RunningDays",
                table: "ReminderSettings",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "1,2,3,4,5,6,7");

            migrationBuilder.AddColumn<bool>(
                name: "RunningEnabled",
                table: "ReminderSettings",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "RunningMinute",
                table: "ReminderSettings",
                type: "int",
                nullable: false,
                defaultValue: 420);

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
