using System.Net;
using System.Security.Cryptography;
using System.Text.Json;
using AiGym.Api.Data;
using AiGym.Api.Dtos;
using Microsoft.EntityFrameworkCore;
using WebPush;

namespace AiGym.Api.Services;

public sealed class NotificationPush
{
    private readonly VapidDetails _vapid;
    public string PublicKey => _vapid.PublicKey;
    public NotificationPush(IWebHostEnvironment environment, IConfiguration config)
    {
        var publicKey = config["NotificationPush:PublicKey"];
        var privateKey = config["NotificationPush:PrivateKey"];
        if (string.IsNullOrEmpty(publicKey) || string.IsNullOrEmpty(privateKey))
        {
            if (!environment.IsDevelopment() && !environment.IsEnvironment("Testing"))
                throw new InvalidOperationException("Configure NotificationPush PublicKey and PrivateKey before production startup.");
            var path = Path.Combine(environment.ContentRootPath, ".local", "notification-vapid.json");
            if (environment.IsEnvironment("Testing"))
            {
                var testKeys = VapidHelper.GenerateVapidKeys(); publicKey = testKeys.PublicKey; privateKey = testKeys.PrivateKey;
            }
            else
            {
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                if (!File.Exists(path))
                {
                    var keys = VapidHelper.GenerateVapidKeys();
                    try { using var stream = new FileStream(path, FileMode.CreateNew); JsonSerializer.Serialize(stream, new { keys.PublicKey, keys.PrivateKey }); }
                    catch (IOException) when (File.Exists(path)) { }
                }
                var stored = JsonDocument.Parse(File.ReadAllText(path));
                publicKey = stored.RootElement.GetProperty("PublicKey").GetString();
                privateKey = stored.RootElement.GetProperty("PrivateKey").GetString();
            }
        }
        _vapid = new VapidDetails(config["NotificationPush:Subject"] ?? "mailto:admin@example.com", publicKey, privateKey);
    }

    public static bool ValidSubscription(PushSubscriptionRequest s)
    {
        if (s.Endpoint is null || s.Endpoint.Length > 2048 || !Uri.TryCreate(s.Endpoint, UriKind.Absolute, out var uri) ||
            uri.Scheme != "https" || uri.Port != 443 || uri.Host != "fcm.googleapis.com" ||
            uri.UserInfo.Length > 0 || uri.Fragment.Length > 0 || string.IsNullOrEmpty(s.SessionId) || s.SessionId.Length > 64) return false;
        try {
            var key=Decode(s.P256dh);
            if(key.Length!=65 || key[0]!=4 || Decode(s.Auth).Length!=16)return false;
            using var curve=ECDiffieHellman.Create(new ECParameters{Curve=ECCurve.NamedCurves.nistP256,Q=new ECPoint{X=key[1..33],Y=key[33..65]}});
            return true;
        }
        catch (Exception error) when (error is FormatException or ArgumentException or NullReferenceException or CryptographicException) { return false; }
    }
    private static byte[] Decode(string value) => Convert.FromBase64String(value.Replace('-', '+').Replace('_', '/').PadRight((value.Length + 3) / 4 * 4, '='));

    public async Task SendPendingAsync(ApplicationDbContext db, DateTime now, CancellationToken cancellationToken)
    {
        var pending = await db.UserNotifications.AsNoTracking().Where(n => !n.PushSent && n.PushAttempts < 3 &&
            (n.NextPushUtc == null || n.NextPushUtc <= now) && (n.PushLeaseUntil == null || n.PushLeaseUntil < now))
            .OrderByDescending(n => n.ScheduledAtUtc).Take(100).ToListAsync(cancellationToken);
        using var handler = new HttpClientHandler { AllowAutoRedirect = false };
        using var http = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(15) };
        using var client = new WebPushClient(http);
        foreach (var n in pending)
        {
            if (db.Database.IsRelational())
            {
                var claimed = await db.UserNotifications.Where(x => x.Id == n.Id && !x.PushSent &&
                    (x.PushLeaseUntil == null || x.PushLeaseUntil < now))
                    .ExecuteUpdateAsync(set => set.SetProperty(x => x.PushLeaseUntil, now.AddMinutes(2)), cancellationToken);
                if (claimed == 0) continue;
            }
            var settings = await db.ReminderSettings.AsNoTracking().SingleOrDefaultAsync(s => s.UserId == n.UserId, cancellationToken);
            var superseded = await db.UserNotifications.AnyAsync(x => x.UserId == n.UserId && x.Kind == n.Kind && x.ScheduledAtUtc > n.ScheduledAtUtc, cancellationToken);
            var done = n.ScheduledAtUtc < now.AddMinutes(-30) || settings is null || !settings.Enabled(n.Kind) ||
                settings.Revision != n.SettingsRevision || superseded;
            if (!done)
            {
                done = true;
                var subscriptions = await db.BrowserPushSubscriptions.Where(s => s.UserId == n.UserId).ToListAsync(cancellationToken);
                foreach (var s in subscriptions)
                {
                    var payload = JsonSerializer.Serialize(new { id = n.Id, kind = n.Kind, title = n.Title, body = n.Body,
                        scheduledAtUtc = n.ScheduledAtUtc, sessionId = s.SessionId });
                    try { await client.SendNotificationAsync(new PushSubscription(s.Endpoint, s.P256dh, s.Auth), payload, _vapid, cancellationToken); }
                    catch (WebPushException ex) when (ex.StatusCode is HttpStatusCode.Gone or HttpStatusCode.NotFound) { db.Remove(s); }
                    catch (Exception ex) when (ex is WebPushException or HttpRequestException or TaskCanceledException) { done = false; }
                }
            }
            var row = await db.UserNotifications.FindAsync([n.Id], cancellationToken);
            if (row is null) continue;
            row.PushSent = done; row.PushAttempts++; row.NextPushUtc = now.AddMinutes(2); row.PushLeaseUntil = null;
            await db.SaveChangesAsync(cancellationToken);
        }
    }
}
