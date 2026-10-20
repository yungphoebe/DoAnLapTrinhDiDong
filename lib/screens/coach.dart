import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_service.dart';
import '../services/lm_studio_service.dart';
import '../services/workout_service.dart';
import '../services/coach_voice_service.dart';
import '../ui.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _aiService = AiService();
  final _lmStudioService = LMStudioService();
  final _workoutService = WorkoutService();
  final _imagePicker = ImagePicker();
  final _voiceService = CoachVoiceService();
  var _isSending = false;
  var _isListening = false;
  var _speechReady = false;
  var _soundEnabled = true;
  String? _voiceName;
  String? _voiceLocale;
  String? _lastFailedMessage;
  String? _conversationId;
  Map<String, dynamic>? _insights;
  final _messages = <({String text, bool fromUser})>[
    (text: 'Xin chào! Bạn muốn hỏi gì về buổi tập hôm nay?', fromUser: false),
  ];

  @override
  void initState() {
    super.initState();
    _restoreConversation();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    final preferences = await SharedPreferences.getInstance();
    _soundEnabled = preferences.getBool('coach.sound') ?? true;
    _voiceName = preferences.getString('coach.voiceName');
    _voiceLocale = preferences.getString('coach.voiceLocale');
    _speechReady = await _voiceService.initializeSpeech(
      onStatus: (status) {
        if (mounted && (status == 'notListening' || status == 'done')) {
          setState(() => _isListening = false);
        }
      },
      onError: (message) {
        if (mounted) {
          setState(() => _isListening = false);
          showMessage(context, 'Không nhận được giọng nói: $message');
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _restoreConversation() async {
    try {
      final conversations = await _aiService.conversations();
      if (!mounted || conversations.isEmpty) return;
      final conversation = conversations.first;
      final messages = (conversation['messages'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => (
              text: '${item['content'] ?? ''}',
              fromUser: item['sender'] == 'user',
            ),
          );
      setState(() {
        _conversationId = '${conversation['id']}';
        _messages
          ..clear()
          ..addAll(messages);
      });
    } catch (_) {}
    try {
      final insights = await _aiService.insights();
      if (mounted) setState(() => _insights = insights);
    } catch (_) {}
  }

  @override
  void dispose() {
    _voiceService.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestion]) async {
    final message = (suggestion ?? _input.text).trim();
    if (message.isEmpty || _isSending) return;
    setState(() {
      _messages.add((text: message, fromUser: true));
      _isSending = true;
      _lastFailedMessage = null;
    });
    _input.clear();
    FocusScope.of(context).unfocus();
    _scrollToBottom();

    try {
      final response = await _aiService.chat(
        message,
        conversationId: _conversationId,
      );
      if (!mounted) return;
      final messages = (response['messages'] as List? ?? const [])
          .whereType<Map>()
          .toList();
      final reply = messages.isEmpty
          ? 'Coach chưa có phản hồi.'
          : '${messages.last['content'] ?? ''}';
      setState(() {
        _conversationId = '${response['id']}';
        _messages.add((text: reply, fromUser: false));
      });
      if (_soundEnabled) {
        await _voiceService.speak(
          reply,
          voiceName: _voiceName,
          locale: _voiceLocale,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastFailedMessage = message;
        _messages.add((
          text: 'Không thể kết nối LMStudio: $error',
          fromUser: false,
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) {
      showMessage(context, 'Microphone chưa sẵn sàng hoặc quyền bị từ chối.');
      return;
    }
    if (_isListening) {
      await _voiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _voiceService.listen(
      onResult: (text, _) {
        if (mounted) {
          _input.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      },
      onError: (message) {
        if (mounted) {
          setState(() => _isListening = false);
          showMessage(context, 'Không nhận được giọng nói: $message');
        }
      },
    );
  }

  Future<void> _speak(String text) async {
    if (!_soundEnabled) return;
    try {
      await _voiceService.speak(
        text,
        voiceName: _voiceName,
        locale: _voiceLocale,
      );
    } catch (error) {
      if (mounted) showMessage(context, 'Không thể đọc phản hồi: $error');
    }
  }

  Future<void> _proposePlan() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      final proposal = await _aiService.planProposal();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${proposal['name'] ?? 'Kế hoạch đề xuất'}'),
          content: Text(
            'Mục tiêu: ${proposal['goal'] ?? 'Tập luyện'}\n'
            'Coach chỉ lưu khi bạn xác nhận.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu kế hoạch'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _workoutService.createPlan(
          name: '${proposal['name'] ?? 'Kế hoạch Coach'}',
          goal: proposal['goal'] as String?,
          level: proposal['level'] as String?,
          exercises: (proposal['exercises'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        );
        if (mounted) showMessage(context, 'Đã lưu kế hoạch vào lịch tập.');
      }
    } catch (error) {
      if (mounted) showMessage(context, 'Không thể tạo kế hoạch: $error');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _analyzeImage() async {
    if (_isSending) return;

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (image == null) return;

    setState(() {
      _messages.add((
        text: 'Hãy phân tích kỹ thuật trong ảnh này.',
        fromUser: true,
      ));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final models = await _lmStudioService.getModels();
      if (models.isEmpty) {
        throw Exception('Không tìm thấy mô hình AI.');
      }
      final reply = await _lmStudioService.chat(
        modelId: models.first,
        prompt: 'Phân tích tư thế tập luyện trong ảnh. Nêu điểm đúng, lỗi cần sửa và một lời khuyên an toàn. Trả lời ngắn gọn.',
        imageBytes: await image.readAsBytes(),
        imageMimeType: _imageMimeType(image.name),
      );
      if (!mounted) return;
      setState(() => _messages.add((text: reply, fromUser: false)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add((
          text: 'Không thể phân tích ảnh. Hãy chọn model Vision và kiểm tra LMStudio đang chạy.',
          fromUser: false,
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  String _imageMimeType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return extension == 'png' ? 'image/png' : 'image/jpeg';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _bubble(({String text, bool fromUser}) message) => Align(
    alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: message.fromUser ? .82 : .91,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: message.fromUser ? GymColors.purple : GymColors.surface,
          border: message.fromUser ? null : Border.all(color: GymColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(message.fromUser ? 15 : 3),
            bottomRight: Radius.circular(message.fromUser ? 3 : 15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                message.text,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
            if (!message.fromUser)
              IconButton(
                tooltip: 'Đọc phản hồi',
                icon: const Icon(Icons.volume_up_outlined, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _speak(message.text),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: GymColors.purple,
              ),
              child: const Icon(
                Icons.psychology_alt,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Coach Pro',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: GymColors.green),
                      SizedBox(width: 5),
                      Text(
                        'Đang trực tuyến',
                        style: TextStyle(fontSize: 11, color: GymColors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.auto_awesome, color: GymColors.purple, size: 22),
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GymCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Text(
                          'MỤC TIÊU HÔM NAY',
                          style: TextStyle(
                            fontSize: 10,
                            color: GymColors.muted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: .7,
                          ),
                        ),
                        Text(
                          _insights?['hasWorkoutData'] == true ||
                                  _insights?['hasNutritionData'] == true
                              ? 'Có dữ liệu thực tế'
                              : 'Chưa có dữ liệu',
                          style: TextStyle(
                            fontSize: 10,
                            color: GymColors.purple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _insights?['message'] as String? ??
                          'Chưa ghi nhận tiến độ mục tiêu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Trao đổi với AI để tham khảo bài tập.',
                      style: TextStyle(fontSize: 11, color: GymColors.muted),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 0,
                        minHeight: 4,
                        color: GymColors.purple,
                        backgroundColor: GymColors.border,
                        semanticsLabel: 'Chưa ghi nhận tiến độ mục tiêu',
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text(
                  'Hội thoại minh họa',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: GymColors.muted),
                ),
              ),
              ..._messages.map(_bubble),
              if (_isSending)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (_lastFailedMessage != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _send(_lastFailedMessage),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Thử lại'),
                  ),
                ),
              Wrap(
                spacing: 7,
                runSpacing: 0,
                children: [
                  for (final suggestion in const {
                    'Tạo lịch tập': 'Tạo lịch tập cho tôi',
                    'Phân tích tiến độ': 'Phân tích tiến độ của tôi',
                    'Chế độ dinh dưỡng': 'Gợi ý chế độ dinh dưỡng',
                  }.entries)
                    ActionChip(
                      label: Text(
                        suggestion.key,
                        style: const TextStyle(
                          fontSize: 10,
                          color: GymColors.muted,
                        ),
                      ),
                      backgroundColor: GymColors.background,
                      side: const BorderSide(color: GymColors.border),
                      shape: const StadiumBorder(),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      onPressed: suggestion.key == 'Tạo lịch tập'
                          ? _proposePlan
                          : () => _send(suggestion.value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/nutrition'),
                icon: const Icon(Icons.restaurant_outlined, size: 18),
                label: const Text('Mở nhật ký dinh dưỡng'),
              ),
              GymCard(
                padding: EdgeInsets.all(13),
                child: Row(
                  children: [
                    SizedBox(
                      width: 49,
                      height: 49,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: 0,
                              strokeWidth: 3,
                              color: GymColors.green,
                              backgroundColor: GymColors.border,
                              semanticsLabel: 'Chưa có dữ liệu phục hồi',
                            ),
                          ),
                          Text(
                            '—',
                            style: TextStyle(
                              color: GymColors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _insights?['hasWorkoutData'] == true
                                ? 'Có dữ liệu tập luyện'
                                : 'Chưa có dữ liệu phục hồi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            _insights?['hasWorkoutData'] == true
                                ? '${_insights!['workoutMinutes']} phút tập hôm nay.'
                                : 'Chưa đủ dữ liệu để đánh giá phục hồi.',
                            style: TextStyle(
                              fontSize: 11,
                              color: GymColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(
          15,
          10,
          15,
          MediaQuery.viewInsetsOf(context).bottom > 0 ? 12 : 32,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: GymColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('coach-input'),
                controller: _input,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Nhắn tin cho Coach...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixIcon: IconButton(
                    tooltip: 'Nhập giọng nói',
                    icon: Icon(
                      _isListening ? Icons.stop_circle_outlined : Icons.mic_none,
                      size: 19,
                    ),
                    onPressed: _isSending ? null : _toggleListening,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Phân tích ảnh',
                    icon: const Icon(Icons.image_outlined, size: 19),
                    onPressed: _isSending ? null : _analyzeImage,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('coach-send'),
              tooltip: 'Gửi tin nhắn',
              onPressed: _isSending ? null : _send,
              style: IconButton.styleFrom(
                backgroundColor: GymColors.purple,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_upward, size: 23),
            ),
          ],
        ),
      ),
    ],
  );
}
