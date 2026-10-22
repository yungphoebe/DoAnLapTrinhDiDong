import 'dart:async';

import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

class NotificationRuntime extends StatefulWidget {
  const NotificationRuntime({super.key, required this.child, this.controller});
  final Widget child;
  final NotificationController? controller;
  static Future<void> Function()? beforeLogout;
  static VoidCallback? sessionChanged;
  static void Function(NotificationLink)? open;
  @override
  State<NotificationRuntime> createState() => _NotificationRuntimeState();
}

class _NotificationRuntimeState extends State<NotificationRuntime>
    with WidgetsBindingObserver {
  late final controller = widget.controller ?? NotificationController.instance;
  NotificationLink? _pending;
  String? _owner;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _owner = controller.owner;
    WidgetsBinding.instance.addObserver(this);
    NotificationRuntime.beforeLogout = controller.logout;
    NotificationRuntime.sessionChanged = () => unawaited(_sync());
    NotificationRuntime.open = _open;
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await controller.initialize(_open);
    } catch (_) {
      controller.deviceMessage = 'Không thể khởi tạo thông báo trên thiết bị.';
    }
    _ready = true;
    if (controller.owner == null) await controller.logout();
    final fragment = Uri.tryParse(Uri.base.fragment);
    if (fragment?.path == '/notification-open') {
      _pending = NotificationLink.fromJson(fragment!.queryParameters);
    }
    await _sync();
  }

  Future<void> _sync() async {
    if (!_ready) return;
    if (_owner != controller.owner) {
      await controller.logout();
      _owner = controller.owner;
    }
    if (controller.owner != null) await controller.load();
    if (_pending != null) {
      final link = _pending!;
      if (controller.owner == null) {
        appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (_) => false,
        );
        return;
      }
      _pending = null;
      if (link.owner == controller.owner) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _open(link);
        });
      }
    }
  }

  void _open(NotificationLink link) {
    if (controller.owner == null || appNavigatorKey.currentState == null) {
      _pending = link;
      return;
    }
    if (controller.owner != link.owner) return;
    if (link.id != null) {
      unawaited(controller.readId(link.id!));
    }
    appNavigatorKey.currentState?.pushNamed(link.route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationRuntime.beforeLogout = null;
    NotificationRuntime.sessionChanged = null;
    NotificationRuntime.open = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
