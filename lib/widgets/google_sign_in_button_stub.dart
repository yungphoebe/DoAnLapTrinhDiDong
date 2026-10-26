import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
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
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: enabled
            ? () => onError(
                'Đăng nhập Google hiện hỗ trợ bản web. Hãy mở ứng dụng trên Chrome.')
            : null,
        child: const Text('Google'),
      );
}
