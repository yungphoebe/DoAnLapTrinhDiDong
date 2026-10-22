import 'package:flutter/material.dart';

import '../ui.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <({String text, bool fromUser})>[
    (
      text: 'Chào Minh Trí, tôi đã tối ưu giáo án Squat hôm nay dựa trên form lưng của bạn ở buổi trước. Bạn đã sẵn sàng bắt đầu chưa?',
      fromUser: false,
    ),
    (
      text: 'Lưng tôi vẫn hơi mỏi, có cần giảm tạ xuống không Coach?',
      fromUser: true,
    ),
    (
      text: 'Có, hãy giảm 10% khối lượng tạ (xuống 80kg) và tập trung giữ thẳng ngực để tránh áp lực lên thắt lưng.',
      fromUser: false,
    ),
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? suggestion]) {
    final message = (suggestion ?? _input.text).trim();
    if (message.isEmpty) return;
    final reply = switch (message) {
      'Tạo lịch tập cho tôi' => 'Phản hồi minh họa: Thứ 2: thân trên. Thứ 4: thân dưới. Thứ 6: toàn thân. Đây là lịch mẫu để bạn khám phá giao diện.',
      'Phân tích tiến độ của tôi' => 'Phản hồi minh họa: Tuần này bạn đã hoàn thành 3/4 buổi tập và duy trì chuỗi 12 ngày. Các chỉ số này là dữ liệu mẫu.',
      'Gợi ý chế độ dinh dưỡng' => 'Phản hồi minh họa: Nhật ký dinh dưỡng mẫu gồm 3 bữa chính và 1 bữa phụ. Tính năng lập thực đơn cá nhân chưa được kết nối.',
      _ => 'Phản hồi minh họa: Mình đã ghi nhận câu hỏi của bạn. Hãy thử các gợi ý lịch tập, tiến độ hoặc dinh dưỡng bên dưới để khám phá hội thoại mẫu.',
    };
    setState(() {
      _messages.add((text: message, fromUser: true));
      _messages.add((text: reply, fromUser: false));
    });
    _input.clear();
    FocusScope.of(context).unfocus();
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
        child: Text(
          message.text,
          style: const TextStyle(fontSize: 13, height: 1.45),
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
                    const Wrap(
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
                          'Hoàn thành 45%',
                          style: TextStyle(
                            fontSize: 10,
                            color: GymColors.purple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Chân & Đùi Trước',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '(Quads & Squat Focus)',
                      style: TextStyle(fontSize: 11, color: GymColors.muted),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: .45,
                        minHeight: 4,
                        color: GymColors.purple,
                        backgroundColor: GymColors.border,
                        semanticsLabel:
                            'Mục tiêu hôm nay hoàn thành 45 phần trăm',
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
                      onPressed: () => _send(suggestion.value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const GymCard(
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
                              value: .78,
                              strokeWidth: 3,
                              color: GymColors.green,
                              backgroundColor: GymColors.border,
                              semanticsLabel: 'Phục hồi minh họa 78 phần trăm',
                            ),
                          ),
                          Text(
                            '78%',
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
                            'Chỉ số phục hồi tốt',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Khuyên dùng mức tạ thông thường cho hôm nay.',
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
                    icon: const Icon(Icons.mic_none, size: 19),
                    onPressed: () => showMessage(
                      context,
                      'Nhập giọng nói chưa có trong bản minh họa.',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('coach-send'),
              tooltip: 'Gửi tin nhắn',
              onPressed: _send,
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
