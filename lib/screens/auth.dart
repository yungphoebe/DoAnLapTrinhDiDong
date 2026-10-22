import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../ui.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.register = false, this.forgot = false});
  final bool register;
  final bool forgot;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  final _authService = AuthService();
  bool _hidden = true, _confirmHidden = true, _accepted = true;
  bool _loading = false;

  // Local demo credentials; no backend authentication or admin permissions.
  bool get _isDemoLogin =>
      !widget.register &&
      !widget.forgot &&
      _contact.text.trim() == 'admin123@gmail.com';

  @override
  void dispose() {
    _fullName.dispose();
    _contact.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _contactValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập email hoặc số điện thoại.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text) &&
        !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(text.replaceAll(' ', ''))) {
      return 'Email hoặc số điện thoại chưa hợp lệ.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (widget.forgot) {
      setState(() => _loading = true);
      try {
        await _authService.forgotPassword(_contact.text);
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Khoi phuc mat khau'),
            content: const Text(
              'Neu email ton tai, he thong da gui huong dan dat lai mat khau.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Da hieu'),
              ),
            ],
          ),
        );
      } on ApiException catch (error) {
        if (!mounted) return;
        showMessage(context, error.message);
      } catch (_) {
        if (!mounted) return;
        showMessage(context, 'Khong the ket noi may chu de gui email.');
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }

      }
      return;
    }

    if (widget.register && !_accepted) {
      showMessage(context, 'Vui lòng đồng ý với điều khoản để tiếp tục.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.register) {
        await _authService.register(
          fullName: _fullName.text,
          email: _contact.text,
          password: _password.text,
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/onboarding');
      } else {
        final auth = await _authService.login(_contact.text, _password.text);
        await _authService.saveSession(auth);
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showMessage(
        context,
        'Không thể kết nối máy chủ. Kiểm tra URL API và tường lửa mạng nội bộ.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loginDemo() async {
    _contact.text = 'admin123@gmail.com';
    _password.text = '123123123Az!';
    await _submit();
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required String fieldKey,
    bool hidden = false,
    VoidCallback? toggle,
    TextEditingController? controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
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
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 19),
            suffixIcon: toggle == null
                ? null
                : IconButton(
                    tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: toggle,
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
    appBar: widget.forgot ? AppBar(leading: const CircleBackButton()) : null,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
            ),
            child: Form(
              key: _form,
              child: Column(
                mainAxisAlignment: widget.forgot
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.forgot) const SizedBox(height: 38),
                  _Logo(compact: widget.register),
                  SizedBox(height: widget.register ? 28 : 76),
                  if (widget.forgot)
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: GymColors.surface,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'Quên mật khẩu',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: GymColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          _authTab('Đăng nhập', !widget.register, '/login'),
                          _authTab('Đăng ký', widget.register, '/register'),
                        ],
                      ),
                    ),
                  if (widget.register)
                    _field(
                      label: 'Họ và tên',
                      hint: 'VD: Minh Trí',
                      icon: Icons.person_outline,
                      fieldKey: 'name-field',
                      controller: _fullName,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Vui lòng nhập họ và tên.'
                          : null,
                    ),
                  _field(
                    label: 'Email / Số điện thoại',
                    hint: widget.register || widget.forgot
                        ? 'VD: tri.nguyen@gym.ai'
                        : 'VD: admin123@gmail.com',
                    icon: Icons.mail_outline,
                    fieldKey: 'email-field',
                    controller: _contact,
                    keyboardType: TextInputType.emailAddress,
                    validator: _contactValidator,
                  ),
                  if (!widget.forgot)
                    _field(
                      label: 'Mật khẩu',
                      hint: widget.register
                          ? 'Tối thiểu 8 ký tự'
                          : '••••••••••••',
                      icon: Icons.lock_outline,
                      fieldKey: 'password-field',
                      controller: _password,
                      hidden: _hidden,
                      toggle: () => setState(() => _hidden = !_hidden),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Vui lòng nhập mật khẩu.';
                        }
                        if (_isDemoLogin && v != '123123123Az!') {
                          return 'Mật khẩu chưa đúng.';
                        }
                        if (widget.register && v.length < 8) {
                          return 'Mật khẩu cần ít nhất 8 ký tự.';
                        }
                        return null;
                      },
                    ),
                  if (widget.register) ...[
                    _field(
                      label: 'Xác nhận mật khẩu',
                      hint: 'Nhập lại mật khẩu',
                      icon: Icons.lock_outline,
                      fieldKey: 'confirm-field',
                      hidden: _confirmHidden,
                      toggle: () =>
                          setState(() => _confirmHidden = !_confirmHidden),
                      validator: (v) => v != _password.text
                          ? 'Mật khẩu xác nhận chưa khớp.'
                          : null,
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Checkbox(
                            value: _accepted,
                            onChanged: (v) => setState(() => _accepted = v!),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Tôi đồng ý với ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: GymColors.muted,
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    Navigator.pushNamed(context, '/terms'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                    'Điều khoản & Chính sách bảo mật',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: GymColors.purple,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else if (!widget.forgot)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/forgot'),
                        child: const Text(
                          'Quên mật khẩu?',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  SizedBox(height: widget.forgot ? 28 : 12),
                  PrimaryButton(
                    label: _loading
                        ? 'Đang xử lý...'
                        : widget.forgot
                        ? 'Gửi OTP xác nhận'
                        : widget.register
                        ? 'Bắt đầu hành trình'
                        : 'Vào phòng tập ngay',
                    icon: widget.register ? null : Icons.arrow_forward,
                    onPressed: _loading ? null : _submit,
                  ),
                  if (!widget.forgot) ...[
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            widget.register
                                ? 'Hoặc đăng ký nhanh'
                                : 'Hoặc tiếp tục với',
                            style: const TextStyle(
                              color: GymColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _socialButton('Apple', Icons.apple),
                        const SizedBox(width: 12),
                        _socialButton('Google', Icons.g_mobiledata),
                        const SizedBox(width: 12),
                        _socialButton('Facebook', Icons.facebook),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading ? null : _loginDemo,
                      child: const Text(
                        'Đăng nhập tài khoản demo',
                        style: TextStyle(fontSize: 11, color: GymColors.muted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _authTab(String text, bool selected, String route) => Expanded(
    child: Material(
      color: selected ? const Color(0xFF292929) : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: selected
            ? null
            : () => Navigator.pushReplacementNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? Colors.white : GymColors.muted,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _socialButton(String label, IconData icon) => Expanded(
    child: Semantics(
      label: 'Tiếp tục với $label',
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: GymColors.surface,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => showMessage(
          context,
          'Đăng nhập $label chưa được kết nối trong bản giao diện.',
        ),
        child: Icon(icon, size: 22),
      ),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: compact ? 44 : 58,
        height: compact ? 44 : 58,
        decoration: BoxDecoration(
          color: const Color(0xFF21172D),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: GymColors.purple),
          boxShadow: [
            BoxShadow(
              color: GymColors.purple.withValues(alpha: .17),
              blurRadius: 22,
            ),
          ],
        ),
        child: Icon(
          Icons.bolt_outlined,
          color: GymColors.purple,
          size: compact ? 31 : 42,
        ),
      ),
      const SizedBox(height: 17),
      Text(
        compact ? 'GYM AI' : 'AI GYM',
        style: TextStyle(
          fontSize: compact ? 19 : 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
      ),
    ],
  );
}
