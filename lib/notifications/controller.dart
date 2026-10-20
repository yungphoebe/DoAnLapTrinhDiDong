import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'platform.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({NotificationApi? api, NotificationPlatform? platform})
    : api = api ?? NotificationApi() {
    this.platform = platform ?? createNotificationPlatform(this.api);
  }
  static final instance = NotificationController();
  final NotificationApi api;
  late final NotificationPlatform platform;
  ReminderSettings settings = const ReminderSettings();
  List<InboxNotification> items = [];
  bool loading = false, saving = false, hasMore = false;
  int unread = 0, _page = 0, _generation = 0;
  String? error, deviceMessage;
  String? _owner;
  final _blocked = <String>{};
  Future<void> _deviceTail = Future<void>.value();
  bool _disposed = false;
  int _sessionEpoch = 0;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  Future<void> _enqueueDevice(Future<void> Function() operation) {
    final result = _deviceTail.catchError((_) {}).then((_) => operation());
    _deviceTail = result;
    return result;
  }

  String? get owner => api.owner;
  bool get blocked => _blocked.isNotEmpty;
  ReminderSettings get localSettings => _effective(settings);
  Future<void> initialize(void Function(NotificationLink) onOpen) =>
      platform.initialize(onOpen);
  Future<void> _device(
    ReminderSettings value,
    String account, {
    bool activate = false,
  }) => _enqueueDevice(() async {
    try {
      if (account != owner || _disposed) return;
      if (activate) {
        deviceMessage = await platform.activate(
          account,
          requestPermission: false,
        );
      }
      if (account == owner) await platform.apply(value, account);
    } catch (_) {
      deviceMessage = 'Cài đặt đã được tải/lưu, nhưng chưa áp dụng được lịch trên thiết bị. Hãy thử bật lại thông báo.';
    }
  });

  ReminderSettings _effective(ReminderSettings s) => s.copyWith(
    workoutEnabled: s.workoutEnabled && !_blocked.contains('workout'),
    waterEnabled: s.waterEnabled && !_blocked.contains('water'),
    weeklyEnabled: s.weeklyEnabled && !_blocked.contains('weekly'),
  );
  Future<void> load({bool more = false}) async {
    if (saving || _disposed) return;
    final account = owner;
    if (account == null) return;
    if (more && (loading || !hasMore)) return;
    final generation = ++_generation;
    if (_owner != account) {
      _sessionEpoch++;
      items = [];
      unread = 0;
      settings = const ReminderSettings();
      _owner = account;
      _blocked.clear();
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation || account != owner || _disposed) return;
      _blocked.addAll(prefs.getStringList('reminder_blocks_$account') ?? []);
      var loaded = more ? settings : await api.settings();
      if (generation != _generation || account != owner || _disposed) return;
      if (!more) {
        String? zone;
        try {
          zone = await platform.timeZone();
        } catch (_) {}
        if (generation != _generation || account != owner || _disposed) return;
        if (zone != null && zone != loaded.timeZone) {
          loaded = await api.save(loaded.copyWith(timeZone: zone));
        }
      }
      if (generation != _generation || account != owner || _disposed) return;
      final data = await api.inbox(more ? _page + 1 : 1);
      if (generation != _generation || account != owner) return;
      settings = loaded;
      final posts = (data['items'] as List)
          .map((j) => InboxNotification.fromJson(j as Map<String, dynamic>))
          .toList();
      if (more) {
        final ids = items.map((n) => n.id).toSet();
        items.addAll(posts.where((n) => ids.add(n.id)));
      } else {
        items = posts;
      }
      _page = more ? _page + 1 : 1;
      hasMore = data['hasMore'] == true;
      unread = data['unreadCount'] as int;
      await _device(_effective(settings), account, activate: true);
    } catch (e) {
      if (generation == _generation) {
        error = 'Không thể tải thông báo/cài đặt. Vui lòng thử lại.';
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(ReminderSettings draft) async {
    final account = owner;
    if (account == null) {
      error = 'Vui lòng đăng nhập để lưu lịch nhắc.';
      notifyListeners();
      return false;
    }
    if (saving) return false;
    final epoch = _sessionEpoch;
    _generation++;
    loading = false;
    saving = true;
    error = null;
    notifyListeners();
    try {
      if (!draft.workoutEnabled) _blocked.add('workout');
      if (!draft.waterEnabled) _blocked.add('water');
      if (!draft.weeklyEnabled) _blocked.add('weekly');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('reminder_blocks_$account', _blocked.toList());
      await _device(_effective(settings), account);
      String zone = settings.timeZone;
      try {
        zone = await platform.timeZone();
      } catch (_) {}
      if (account != owner || _disposed || epoch != _sessionEpoch) return false;
      final saved = await api.save(
        draft.copyWith(timeZone: zone, revision: settings.revision),
      );
      if (account != owner || epoch != _sessionEpoch) return false;
      settings = saved;
      _blocked.clear();
      await prefs.remove('reminder_blocks_$account');
      await _device(settings, account, activate: true);
      return true;
    } catch (e) {
      if (account != owner || epoch != _sessionEpoch) return false;
      error = 'Chưa lưu được cài đặt. Nhắc đã tắt trên máy này vẫn được chặn; hãy thử lưu lại.';
      return false;
    } finally {
      if (epoch == _sessionEpoch) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<void> enableDevice() async {
    final account = owner;
    if (account == null) return;
    final epoch = _sessionEpoch;
    try {
      final permission = await platform.requestPermission();
      if (account != owner || epoch != _sessionEpoch || _disposed) return;
      if (permission != null) {
        deviceMessage = permission;
        notifyListeners();
        return;
      }
      await _enqueueDevice(() async {
        if (account != owner || epoch != _sessionEpoch || _disposed) return;
        deviceMessage = await platform.activate(
          account,
          requestPermission: false,
        );
        if (account == owner && !_disposed) {
          await platform.apply(_effective(settings), account);
        }
      });
    } catch (_) {
      deviceMessage = 'Không thể bật thông báo trên thiết bị. Kiểm tra quyền và kết nối rồi thử lại.';
    }
    notifyListeners();
  }

  Future<void> read(InboxNotification n) async {
    final account = owner;
    final generation = _generation;
    try {
      await api.read(n.id);
      if (account != owner || generation != _generation || _disposed) return;
      if (!n.read) {
        n.read = true;
        if (unread > 0) unread--;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> readId(String id) async {
    final account = owner;
    try {
      await api.read(id);
      if (account == owner && !_disposed) await load();
    } catch (_) {}
  }

  Future<bool> readAll() async {
    final account = owner;
    final generation = _generation;
    try {
      await api.readAll();
      if (account != owner || generation != _generation || _disposed) {
        return false;
      }
      for (final n in items) {
        n.read = true;
      }
      unread = 0;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _generation++;
    _sessionEpoch++;
    try {
      await _enqueueDevice(platform.deactivate);
    } catch (_) {
      deviceMessage = 'Chưa hủy được lịch trên thiết bị. Hãy kiểm tra cài đặt thông báo hệ thống.';
    }
    items = [];
    unread = 0;
    _owner = null;
    settings = const ReminderSettings();
    _blocked.clear();
    error = null;
    loading = false;
    saving = false;
    notifyListeners();
  }
}
