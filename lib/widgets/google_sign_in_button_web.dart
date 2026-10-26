import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../services/api_client.dart';

@JS('gymGoogleSignIn.render')
external JSPromise<JSAny?> _renderGoogle(
  JSObject element,
  JSString clientId,
  JSFunction callback,
);

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onCredential,
    required this.onError,
    this.enabled = true,
  });

  final Future<void> Function(String) onCredential;
  final ValueChanged<String> onError;
  final bool enabled;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  String? _clientId;
  String? _error;
  bool _fetching = true;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    setState(() {
      _fetching = true;
      _error = null;
    });
    try {
      final response = await ApiClient.instance
          .get('/api/auth/google/config')
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final id = body['clientId'] as String?;
      if (response.statusCode != 200 || id == null || id.isEmpty) {
        throw StateError(
            body['message']?.toString() ?? 'Chưa cấu hình đăng nhập Google.');
      }
      if (mounted) setState(() => _clientId = id);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
            ? error.message.toString()
            : 'Không tải được đăng nhập Google. Kiểm tra backend và kết nối mạng, rồi thử lại.');
      }
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _render(Object object) async {
    final element = object as web.HTMLElement;
    element.style
      ..display = 'flex'
      ..justifyContent = 'center'
      ..alignItems = 'center';
    try {
      await _renderGoogle(
              element,
              _clientId!.toJS,
              ((JSString token) {
                if (mounted && widget.enabled) {
                  widget.onCredential(token.toDart);
                }
              }).toJS)
          .toDart;
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Không tải được Google. Kiểm tra mạng hoặc trình chặn nội dung rồi bấm thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fetching) {
      return const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ));
    }
    if (_error != null) {
      return Tooltip(
        message: _error!,
        child: OutlinedButton(
          onPressed: widget.enabled
              ? () {
                  widget.onError(_error!);
                  _loadConfiguration();
                }
              : null,
          child: const Text('Google'),
        ),
      );
    }
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : .5,
        child: SizedBox(
          height: 44,
          child: HtmlElementView.fromTagName(
            tagName: 'div',
            onElementCreated: _render,
          ),
        ),
      ),
    );
  }
}
