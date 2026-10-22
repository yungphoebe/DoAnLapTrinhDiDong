import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../ui.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.token,
  });

  final String email;
  final String token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _authService = AuthService();
  bool _hidden = true;
  bool _confirmHidden = true;
  bool _loading = false;

  bool get _hasValidLink =>
      widget.email.trim().isNotEmpty && widget.token.trim().isNotEmpty;

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_hasValidLink || !_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _authService.resetPassword(
        email: widget.email,
        token: widget.token,
        newPassword: _password.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Da doi mat khau'),
          content: const Text('Ban co the dang nhap bang mat khau moi.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dang nhap'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showMessage(context, 'Khong the ket noi may chu de doi mat khau.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool hidden,
    required VoidCallback onToggle,
    required String fieldKey,
    required String? Function(String?) validator,
  }) => Padding(
    padding: const EdgeInsets.only(top: 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: Key(fieldKey),
          controller: controller,
          obscureText: hidden,
          validator: validator,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.lock_outline, size: 19),
            suffixIcon: IconButton(
              tooltip: hidden ? 'Hien mat khau' : 'An mat khau',
              onPressed: onToggle,
              icon: Icon(
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: const CircleBackButton()),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 52),
              const Icon(
                Icons.bolt_outlined,
                color: GymColors.purple,
                size: 48,
              ),
              const SizedBox(height: 18),
              const Text(
                'Tao mat khau moi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                _hasValidLink
                    ? widget.email
                    : 'Link dat lai mat khau khong hop le.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: GymColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 42),
              if (!_hasValidLink)
                PrimaryButton(
                  label: 'Quay ve dang nhap',
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  ),
                )
              else ...[
                _passwordField(
                  controller: _password,
                  label: 'Mat khau moi',
                  hint: 'Toi thieu 8 ky tu',
                  hidden: _hidden,
                  onToggle: () => setState(() => _hidden = !_hidden),
                  fieldKey: 'new-password-field',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui long nhap mat khau moi.';
                    }
                    if (value.length < 8) {
                      return 'Mat khau can it nhat 8 ky tu.';
                    }
                    return null;
                  },
                ),
                _passwordField(
                  controller: _confirmPassword,
                  label: 'Xac nhan mat khau',
                  hint: 'Nhap lai mat khau moi',
                  hidden: _confirmHidden,
                  onToggle: () =>
                      setState(() => _confirmHidden = !_confirmHidden),
                  fieldKey: 'confirm-new-password-field',
                  validator: (value) => value != _password.text
                      ? 'Mat khau xac nhan chua khop.'
                      : null,
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: _loading ? 'Dang doi mat khau...' : 'Doi mat khau',
                  icon: Icons.check,
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
