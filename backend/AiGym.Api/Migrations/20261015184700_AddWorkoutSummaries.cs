using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AiGym.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkoutSummaries : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ExercisesJson",
                table: "WorkoutSessions",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "[]");

            migrationBuilder.AddColumn<string>(
                name: "FeedbackCountsJson",
                table: "WorkoutSessions",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "{}");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ExercisesJson",
                table: "WorkoutSessions");

            migrationBuilder.DropColumn(
                name: "FeedbackCountsJson",
                table: "WorkoutSessions");
        }
    }
}
