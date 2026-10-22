using AiGym.Api.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace AiGym.Api.Data;

public sealed class ApplicationDbContext : IdentityDbContext<ApplicationUser>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<Post> Posts => Set<Post>();
    public DbSet<PostLike> PostLikes => Set<PostLike>();
    public DbSet<PostComment> PostComments => Set<PostComment>();
    public DbSet<ReminderSettings> ReminderSettings => Set<ReminderSettings>();
    public DbSet<UserNotification> UserNotifications => Set<UserNotification>();
    public DbSet<BrowserPushSubscription> BrowserPushSubscriptions => Set<BrowserPushSubscription>();
    public DbSet<UserFeedback> UserFeedback => Set<UserFeedback>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);
        builder.Entity<PostComment>(entity =>
        {
            entity.HasKey(comment => comment.Id);
            entity.Property(comment => comment.Id).ValueGeneratedNever();
            entity.Property(comment => comment.AuthorId).HasMaxLength(450).IsRequired();
            entity.Property(comment => comment.Content).HasMaxLength(1000).IsRequired();
            // SQL Server datetime2 does not retain DateTime.Kind; API dates are UTC.
            entity.Property(comment => comment.CreatedAt).HasConversion(
                value => value, value => DateTime.SpecifyKind(value, DateTimeKind.Utc));
            entity.Property(comment => comment.UpdatedAt).HasConversion(
                value => value,
                value => value.HasValue ? DateTime.SpecifyKind(value.Value, DateTimeKind.Utc) : (DateTime?)null);
            entity.HasIndex(comment => new { comment.PostId, comment.CreatedAt, comment.Id });
            entity.HasOne(comment => comment.Post).WithMany(post => post.Comments)
                .HasForeignKey(comment => comment.PostId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(comment => comment.Author).WithMany()
                .HasForeignKey(comment => comment.AuthorId).OnDelete(DeleteBehavior.NoAction);
        });
        builder.Entity<UserFeedback>(e => {
            e.HasKey(f=>f.Id);e.Property(f=>f.UserId).HasMaxLength(450);
            e.Property(f=>f.Subject).HasMaxLength(120);e.Property(f=>f.Content).HasMaxLength(4000);
            e.Property(f => f.CreatedAt).HasConversion(
                value => value, value => DateTime.SpecifyKind(value, DateTimeKind.Utc));
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(f=>f.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<ReminderSettings>(e =>
        {
            e.HasKey(s => s.UserId); e.Property(s => s.UserId).HasMaxLength(450);
            e.Property(s => s.WorkoutDays).HasMaxLength(20); e.Property(s => s.TimeZone).HasMaxLength(100);
            e.Property(s => s.Revision).IsConcurrencyToken();
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(s => s.UserId).OnDelete(DeleteBehavior.Cascade);
        });
        builder.Entity<UserNotification>(e =>
        {
            e.HasKey(n => n.Id); e.Property(n => n.UserId).HasMaxLength(450);
            e.Property(n => n.Kind).HasMaxLength(20); e.Property(n => n.Title).HasMaxLength(200);
            e.Property(n => n.Body).HasMaxLength(500); e.HasIndex(n => new { n.UserId, n.ScheduledAtUtc });
            // datetime2 stores UTC values without retaining DateTime.Kind.
            e.Property(n => n.ScheduledAtUtc).HasConversion(
                value => value, value => DateTime.SpecifyKind(value, DateTimeKind.Utc));
            e.Property(n => n.CreatedAt).HasConversion(
                value => value, value => DateTime.SpecifyKind(value, DateTimeKind.Utc));
            e.Property(n => n.ReadAt).HasConversion(
                value => value,
                value => value.HasValue ? DateTime.SpecifyKind(value.Value, DateTimeKind.Utc) : (DateTime?)null);
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(n => n.UserId).OnDelete(DeleteBehavior.Cascade);
        });
        builder.Entity<BrowserPushSubscription>(e =>
        {
            e.HasKey(s => s.Id); e.Property(s => s.Id).HasMaxLength(64);
            e.Property(s => s.UserId).HasMaxLength(450); e.HasIndex(s => s.UserId);
            e.Property(s => s.Endpoint).HasMaxLength(2048); e.Property(s => s.P256dh).HasMaxLength(100);
            e.Property(s => s.Auth).HasMaxLength(32); e.Property(s => s.SessionId).HasMaxLength(64);
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(s => s.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<ApplicationUser>()
            .Property(user => user.FullName)
            .HasMaxLength(120)
            .IsRequired();

        builder.Entity<Post>(entity =>
        {
            entity.Property(post => post.AuthorName).HasMaxLength(120).IsRequired();
            entity.Property(post => post.Content).HasMaxLength(1000).IsRequired();
            entity.Property(post => post.ImageAsset).HasMaxLength(255);
            entity.Property(post => post.Tag).HasMaxLength(50).IsRequired();
            entity.HasOne(post => post.Author)
                .WithMany()
                .HasForeignKey(post => post.AuthorId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<PostLike>(entity =>
        {
            entity.HasKey(like => new { like.PostId, like.UserId });
            entity.Property(like => like.UserId).HasMaxLength(450);
            entity.HasOne(like => like.Post).WithMany(post => post.Likes)
                .HasForeignKey(like => like.PostId).OnDelete(DeleteBehavior.Cascade);
            // Avoid SQL Server's multiple cascade paths through the post author.
            entity.HasOne<ApplicationUser>().WithMany()
                .HasForeignKey(like => like.UserId).OnDelete(DeleteBehavior.NoAction);
        });
    }
}
