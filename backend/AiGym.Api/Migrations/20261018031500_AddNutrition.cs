using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AiGym.Api.Migrations;

public partial class AddNutrition : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable("Foods", table => new
        {
            Id = table.Column<Guid>(nullable: false),
            Name = table.Column<string>(maxLength: 160, nullable: false),
            Brand = table.Column<string>(maxLength: 120, nullable: true),
            CaloriesPer100g = table.Column<decimal>(type: "decimal(10,2)", nullable: false),
            ProteinPer100g = table.Column<decimal>(type: "decimal(10,2)", nullable: false),
            CarbsPer100g = table.Column<decimal>(type: "decimal(10,2)", nullable: false),
            FatPer100g = table.Column<decimal>(type: "decimal(10,2)", nullable: false)
        }, constraints: table => table.PrimaryKey("PK_Foods", x => x.Id));
        migrationBuilder.CreateTable("Meals", table => new
        {
            Id = table.Column<Guid>(nullable: false), UserId = table.Column<string>(nullable: false),
            ConsumedAt = table.Column<DateTimeOffset>(nullable: false), Name = table.Column<string>(maxLength: 120, nullable: false),
            Calories = table.Column<decimal>(type: "decimal(10,2)", nullable: false), Protein = table.Column<decimal>(type: "decimal(10,2)", nullable: false),
            Carbs = table.Column<decimal>(type: "decimal(10,2)", nullable: false), Fat = table.Column<decimal>(type: "decimal(10,2)", nullable: false)
        }, constraints: table => { table.PrimaryKey("PK_Meals", x => x.Id); table.ForeignKey("FK_Meals_AspNetUsers_UserId", x => x.UserId, "AspNetUsers", "Id", onDelete: ReferentialAction.Cascade); });
        migrationBuilder.CreateTable("DailyCalorieTargets", table => new
        {
            Id = table.Column<Guid>(nullable: false), UserId = table.Column<string>(nullable: false), Date = table.Column<DateOnly>(nullable: false),
            Calories = table.Column<decimal>(nullable: false), Protein = table.Column<decimal>(nullable: false), Carbs = table.Column<decimal>(nullable: false),
            Fat = table.Column<decimal>(nullable: false), Source = table.Column<string>(maxLength: 30, nullable: false)
        }, constraints: table => { table.PrimaryKey("PK_DailyCalorieTargets", x => x.Id); table.ForeignKey("FK_DailyCalorieTargets_AspNetUsers_UserId", x => x.UserId, "AspNetUsers", "Id", onDelete: ReferentialAction.Cascade); });
        migrationBuilder.CreateTable("ConfirmedScanResults", table => new
        {
            Id = table.Column<Guid>(nullable: false), UserId = table.Column<string>(nullable: false), IdempotencyKey = table.Column<string>(maxLength: 120, nullable: true),
            FoodName = table.Column<string>(maxLength: 160, nullable: false), EstimatedGrams = table.Column<decimal>(nullable: false), Calories = table.Column<decimal>(nullable: false),
            Protein = table.Column<decimal>(nullable: false), Carbs = table.Column<decimal>(nullable: false), Fat = table.Column<decimal>(nullable: false),
            IsFallbackEstimate = table.Column<bool>(nullable: false), CreatedAt = table.Column<DateTimeOffset>(nullable: false)
        }, constraints: table => { table.PrimaryKey("PK_ConfirmedScanResults", x => x.Id); table.ForeignKey("FK_ConfirmedScanResults_AspNetUsers_UserId", x => x.UserId, "AspNetUsers", "Id", onDelete: ReferentialAction.Cascade); });
        migrationBuilder.CreateTable("MealItems", table => new
        {
            Id = table.Column<Guid>(nullable: false), MealId = table.Column<Guid>(nullable: false), FoodId = table.Column<Guid>(nullable: false),
            Servings = table.Column<decimal>(nullable: false), Grams = table.Column<decimal>(nullable: false)
        }, constraints: table => { table.PrimaryKey("PK_MealItems", x => x.Id); table.ForeignKey("FK_MealItems_Foods_FoodId", x => x.FoodId, "Foods", "Id", onDelete: ReferentialAction.Restrict); table.ForeignKey("FK_MealItems_Meals_MealId", x => x.MealId, "Meals", "Id", onDelete: ReferentialAction.Cascade); });
        migrationBuilder.CreateIndex("IX_Foods_Name", "Foods", "Name");
        migrationBuilder.CreateIndex("IX_Meals_UserId_ConsumedAt", "Meals", new[] { "UserId", "ConsumedAt" });
        migrationBuilder.CreateIndex("IX_MealItems_FoodId", "MealItems", "FoodId");
        migrationBuilder.CreateIndex("IX_DailyCalorieTargets_UserId_Date", "DailyCalorieTargets", new[] { "UserId", "Date" }, unique: true);
        migrationBuilder.CreateIndex("IX_ConfirmedScanResults_UserId_IdempotencyKey", "ConfirmedScanResults", new[] { "UserId", "IdempotencyKey" }, unique: true);
        migrationBuilder.CreateIndex("IX_MealItems_MealId", "MealItems", "MealId");
    }
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable("MealItems"); migrationBuilder.DropTable("ConfirmedScanResults"); migrationBuilder.DropTable("DailyCalorieTargets"); migrationBuilder.DropTable("Meals"); migrationBuilder.DropTable("Foods");
    }
}
