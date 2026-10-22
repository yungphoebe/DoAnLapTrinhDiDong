import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../ui.dart';
import '../services/api_client.dart';
import 'api.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.api, this.document});
  final SupportApi? api;
  final String? document;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final api = widget.api ?? SupportApi();
  late Future<Map<String, dynamic>> _content = api.content();
  final Future<PackageInfo?> _version = PackageInfo.fromPlatform()
      .then<PackageInfo?>((info) => info)
      .catchError((_) => null);
  static const titles = {
    'guide': 'Hướng dẫn sử dụng',
    'terms': 'Điều khoản sử dụng',
    'privacy': 'Chính sách riêng tư',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(titles[widget.document] ?? 'Trợ giúp & Phản hồi'),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được nội dung từ máy chủ.'),
                TextButton(
                  onPressed: () => setState(() => _content = api.content()),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        final data = snapshot.data!;
        if (widget.document != null) {
          final text = data[widget.document] as String?;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (data['groupName'] != null) Text(data['groupName'] as String),
              SelectableText(
                text == null || text.trim().isEmpty
                    ? 'Nhóm chưa cung cấp nội dung'
                    : text,
                style: const TextStyle(height: 1.6),
              ),
              if (widget.document == 'terms')
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          SupportScreen(api: api, document: 'privacy'),
                    ),
                  ),
                  child: const Text('Xem Chính sách riêng tư'),
                ),
              if (data['updatedAt'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('Cập nhật: ${data['updatedAt']}'),
                ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FutureBuilder<PackageInfo?>(
              future: _version,
              builder: (context, version) => GymCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI GYM',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      version.data == null
                          ? 'Chưa đọc được phiên bản ứng dụng'
                          : 'Phiên bản ${version.data!.version} (${version.data!.buildNumber})',
                    ),
                    if (data['groupName'] != null)
                      Text(data['groupName'] as String),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in titles.entries)
              ListTile(
                title: Text(entry.value),
                subtitle: Text(
                  data[entry.key] == null
                      ? 'Nhóm chưa cung cấp nội dung'
                      : 'Nội dung do nhóm cung cấp',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SupportScreen(api: api, document: entry.key),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Gửi phản hồi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FeedbackScreen(api: api),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.api});
  final SupportApi? api;
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController(), _content = TextEditingController();
  bool _sending = false;
  String? _error, _success, _fingerprint, _id;
  @override
  void dispose() {
    _subject.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    final fingerprint = '${_subject.text.trim()}\u0000${_content.text.trim()}';
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _id = SupportApi.requestId();
    }
    setState(() {
      _sending = true;
      _error = null;
      _success = null;
    });
    try {
      final id = await (widget.api ?? SupportApi()).feedback(
        _id!,
        _subject.text,
        _content.text,
      );
      if (!mounted) return;
      setState(() {
        _success = 'Đã gửi phản hồi thành công. Mã xác nhận: $id';
        _content.clear();
        _subject.clear();
        _fingerprint = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không kết nối được máy chủ. Nội dung vẫn được giữ để thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gửi phản hồi')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            key: const Key('feedback-subject'),
            controller: _subject,
            enabled: !_sending,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Tiêu đề (tùy chọn)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('feedback-content'),
            controller: _content,
            enabled: !_sending,
            maxLength: 4000,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Nội dung phản hồi'),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Vui lòng nhập nội dung phản hồi.'
                : null,
          ),
          if (_error != null)
            Text(
              _error!,
              key: const Key('feedback-error'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          if (_success != null)
            SelectableText(_success!, key: const Key('feedback-success')),
          const SizedBox(height: 16),
          PrimaryButton(
            key: const Key('send-feedback'),
            label: _sending ? 'Đang gửi…' : 'Gửi phản hồi',
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    ),
  );
}
