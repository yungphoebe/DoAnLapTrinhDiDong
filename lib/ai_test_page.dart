import 'package:flutter/material.dart';

import 'services/lm_studio_service.dart';

class AITestPage extends StatefulWidget {
  const AITestPage({super.key});

  @override
  State<AITestPage> createState() => _AITestPageState();
}

class _AITestPageState extends State<AITestPage> {
  final _ai = LMStudioService();
  final _promptController = TextEditingController(
    text: 'Hãy giới thiệu về khả năng của bạn bằng tiếng Việt.',
  );
  String _result = 'Chưa kết nối';
  String? _modelId;
  bool _loading = false;

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _result = 'Đang kết nối...';
    });
    try {
      final models = await _ai.getModels();
      if (models.isEmpty) throw Exception('Không tìm thấy mô hình AI.');
      setState(() {
        _modelId = models.first;
        _result = 'Kết nối thành công!\nModel: $_modelId';
      });
    } catch (error) {
      setState(() => _result = 'Lỗi kết nối:\n$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _askAi() async {
    if (_modelId == null) {
      await _connect();
      if (_modelId == null) return;
    }
    setState(() {
      _loading = true;
      _result = 'AI đang xử lý...';
    });
    try {
      final answer = await _ai.chat(
        modelId: _modelId!,
        prompt: _promptController.text.trim(),
      );
      setState(() => _result = answer);
    } catch (error) {
      setState(() => _result = 'Lỗi AI:\n$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LM Studio Local AI')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          ElevatedButton(
            onPressed: _loading ? null : _connect,
            child: const Text('1. Kiểm tra kết nối'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Câu hỏi AI',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _askAi,
            child: const Text('2. Gửi câu hỏi'),
          ),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          SelectableText(_result),
        ],
      ),
    ),
  );
}
