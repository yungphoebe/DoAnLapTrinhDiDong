using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AiGym.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddMealItemNutrition : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<Guid>(
                name: "FoodId",
                table: "MealItems",
                type: "uniqueidentifier",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier");

            migrationBuilder.AddColumn<decimal>(
                name: "Calories",
                table: "MealItems",
                type: "decimal(10,2)",
                precision: 10,
                scale: 2,
                nullable: false,
                defaultValue: 0m);



            migrationBuilder.AddColumn<decimal>(
                name: "Carbs",
                table: "MealItems",
                type: "decimal(10,2)",
                precision: 10,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "Fat",
                table: "MealItems",
                type: "decimal(10,2)",
                precision: 10,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "FoodName",
                table: "MealItems",
                type: "nvarchar(160)",
                maxLength: 160,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<decimal>(
                name: "Protein",
                table: "MealItems",
                type: "decimal(10,2)",
                precision: 10,
                scale: 2,
                nullable: false,
                defaultValue: 0m);
            migrationBuilder.Sql("""
                UPDATE i SET i.FoodName = f.Name,
                    i.Calories = f.CaloriesPer100g * i.Grams / 100,
                    i.Protein = f.ProteinPer100g * i.Grams / 100,
                    i.Carbs = f.CarbsPer100g * i.Grams / 100,
                    i.Fat = f.FatPer100g * i.Grams / 100
                FROM MealItems i INNER JOIN Foods f ON i.FoodId = f.Id;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                IF EXISTS (SELECT 1 FROM MealItems WHERE FoodId IS NULL)
                    THROW 50001, 'Cannot roll back while custom nutrition meal items exist.', 1;
                """);
            migrationBuilder.DropColumn(
                name: "Calories",
                table: "MealItems");

            migrationBuilder.DropColumn(
                name: "Carbs",
                table: "MealItems");

            migrationBuilder.DropColumn(
                name: "Fat",
                table: "MealItems");

            migrationBuilder.DropColumn(
                name: "FoodName",
                table: "MealItems");

            migrationBuilder.DropColumn(
                name: "Protein",
                table: "MealItems");

            migrationBuilder.AlterColumn<Guid>(
                name: "FoodId",
                table: "MealItems",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);
        }
    }
}

