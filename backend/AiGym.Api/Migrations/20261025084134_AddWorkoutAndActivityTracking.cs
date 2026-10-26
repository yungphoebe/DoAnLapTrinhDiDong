using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AiGym.Api.Migrations;

public partial class AddWorkoutAndActivityTracking : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<int>(
            name: "DaysPerWeek",
            table: "WorkoutPlans",
            type: "int",
            nullable: false,
            defaultValue: 3);
        migrationBuilder.AddColumn<int>(
            name: "SessionMinutes",
            table: "WorkoutPlans",
            type: "int",
            nullable: false,
            defaultValue: 45);
        migrationBuilder.AddColumn<string>(
            name: "TrainingLocation",
            table: "WorkoutPlans",
            type: "nvarchar(60)",
            maxLength: 60,
            nullable: true);
        migrationBuilder.AddColumn<string>(
            name: "Equipment",
            table: "WorkoutPlans",
            type: "nvarchar(500)",
            maxLength: 500,
            nullable: true);
        migrationBuilder.AddColumn<int>(
            name: "DayNumber",
            table: "WorkoutPlanExercises",
            type: "int",
            nullable: false,
            defaultValue: 1);
        migrationBuilder.AddColumn<int>(
            name: "TargetSeconds",
            table: "WorkoutPlanExercises",
            type: "int",
            nullable: true);

        migrationBuilder.CreateTable(
            name: "ActivitySessions",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                ActivityType = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                StartedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                DurationSeconds = table.Column<int>(type: "int", nullable: false),
                Steps = table.Column<int>(type: "int", nullable: true),
                DistanceMeters = table.Column<double>(type: "float", nullable: true),
                DistanceEstimated = table.Column<bool>(type: "bit", nullable: false),
                Completed = table.Column<bool>(type: "bit", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_ActivitySessions", x => x.Id);
                table.ForeignKey(
                    name: "FK_ActivitySessions_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "DailyActivityGoals",
            columns: table => new
            {
                UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                Date = table.Column<DateOnly>(type: "date", nullable: false),
                StepsGoal = table.Column<int>(type: "int", nullable: false),
                MinutesGoal = table.Column<int>(type: "int", nullable: false),
                DistanceGoalKm = table.Column<decimal>(
                    type: "decimal(10,2)", precision: 10, scale: 2, nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_DailyActivityGoals", x => new { x.UserId, x.Date });
                table.ForeignKey(
                    name: "FK_DailyActivityGoals_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "WorkoutPlanExerciseResults",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                WorkoutPlanId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                WorkoutPlanExerciseId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                StartedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                DurationSeconds = table.Column<int>(type: "int", nullable: false),
                ActualSets = table.Column<int>(type: "int", nullable: false),
                ActualReps = table.Column<int>(type: "int", nullable: false),
                Completed = table.Column<bool>(type: "bit", nullable: false),
                FeedbackJson = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_WorkoutPlanExerciseResults", x => x.Id);
                table.ForeignKey(
                    name: "FK_WorkoutPlanExerciseResults_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_WorkoutPlanExerciseResults_WorkoutPlanExercises_WorkoutPlanExerciseId",
                    column: x => x.WorkoutPlanExerciseId,
                    principalTable: "WorkoutPlanExercises",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_WorkoutPlanExerciseResults_WorkoutPlans_WorkoutPlanId",
                    column: x => x.WorkoutPlanId,
                    principalTable: "WorkoutPlans",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_ActivitySessions_UserId_StartedAt",
            table: "ActivitySessions",
            columns: new[] { "UserId", "StartedAt" });
        migrationBuilder.CreateIndex(
            name: "IX_WorkoutPlanExerciseResults_UserId_StartedAt",
            table: "WorkoutPlanExerciseResults",
            columns: new[] { "UserId", "StartedAt" });
        migrationBuilder.CreateIndex(
            name: "IX_WorkoutPlanExerciseResults_WorkoutPlanExerciseId",
            table: "WorkoutPlanExerciseResults",
            column: "WorkoutPlanExerciseId");
        migrationBuilder.CreateIndex(
            name: "IX_WorkoutPlanExerciseResults_WorkoutPlanId_WorkoutPlanExerciseId_StartedAt",
            table: "WorkoutPlanExerciseResults",
            columns: new[] { "WorkoutPlanId", "WorkoutPlanExerciseId", "StartedAt" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "ActivitySessions");
        migrationBuilder.DropTable(name: "DailyActivityGoals");
        migrationBuilder.DropTable(name: "WorkoutPlanExerciseResults");
        migrationBuilder.DropColumn(name: "DaysPerWeek", table: "WorkoutPlans");
        migrationBuilder.DropColumn(name: "SessionMinutes", table: "WorkoutPlans");
        migrationBuilder.DropColumn(name: "TrainingLocation", table: "WorkoutPlans");
        migrationBuilder.DropColumn(name: "Equipment", table: "WorkoutPlans");
        migrationBuilder.DropColumn(name: "DayNumber", table: "WorkoutPlanExercises");
        migrationBuilder.DropColumn(name: "TargetSeconds", table: "WorkoutPlanExercises");
    }
}
