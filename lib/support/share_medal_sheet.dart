import 'package:flutter/material.dart';

import '../services/post_api.dart';
import '../ui.dart';

class ShareMedalSheet extends StatefulWidget {
  const ShareMedalSheet({
    super.key,
    required this.medalTitle,
    required this.medalDescription,
    required this.emoji,
    this.color = const Color(0xFFFFD700),
    this.earnedDate,
  });

  final String medalTitle;
  final String medalDescription;
  final String emoji;
  final Color color;
  final String? earnedDate;

  static Future<void> show({
    required BuildContext context,
    required String medalTitle,
    required String medalDescription,
    required String emoji,
    Color color = const Color(0xFFFFD700),
    String? earnedDate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareMedalSheet(
        medalTitle: medalTitle,
        medalDescription: medalDescription,
        emoji: emoji,
        color: color,
        earnedDate: earnedDate,
      ),
    );
  }

  @override
  State<ShareMedalSheet> createState() => _ShareMedalSheetState();
}

class _ShareMedalSheetState extends State<ShareMedalSheet> {
  late final TextEditingController _contentCtrl;
  bool _loading = false;
  String _shareTarget = 'community'; // 'community' | 'pt'
  String? _selectedPt;

  final List<Map<String, String>> _ptList = [
    {
      'name': 'HLV. Hải Đăng',
      'role': 'PT Cá nhân (Đốt mỡ & Tăng cơ)',
      'avatar': 'assets/images/trainer.jpg',
    },
    {
      'name': 'PT. Thu Hà',
      'role': 'PT Chuyên môn (Mobility & Giữ dáng)',
      'avatar': 'assets/images/trainer.jpg',
    },
    {
      'name': 'Minh Anh',
      'role': 'Bạn tập cùng (Cardio & Dinh dưỡng)',
      'avatar': 'assets/images/avatar.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(
      text:
          '🎉 Tôi vừa mở khóa thành công ${widget.medalTitle}! 🏅\n'
          '"${widget.medalDescription}"\n'
          'Cùng nhau rèn luyện và bứt phá mục tiêu nhé! 💪🔥',
    );
    _selectedPt = _ptList.first['name'];
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _loading = true);
    try {
      if (_shareTarget == 'community') {
        // Đăng trực tiếp lên Newsfeed Cộng đồng qua PostApi
        await PostApi().createPost(text);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GymColors.surface,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: GymColors.green, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Đã chia sẻ huy chương lên Bảng tin Cộng đồng! 🎉'),
                ),
              ],
            ),
          ),
        );
      } else {
        // Chia sẻ cho PT / Bạn tập
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GymColors.surface,
            content: Row(
              children: [
                const Icon(Icons.send_rounded, color: GymColors.purple, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Đã gửi thành tích đến $_selectedPt! 💪'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade900,
          content: Text('Lỗi chia sẻ: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: GymColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: GymColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: GymColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.share_rounded, color: GymColors.purple, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Chia Sẻ Huy Chương',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: GymColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Card Huy chương Preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GymColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.color.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(alpha: 0.15),
                      border: Border.all(color: widget.color, width: 2),
                    ),
                    child: Center(
                      child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.medalTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.medalDescription,
                          style: const TextStyle(fontSize: 12, color: GymColors.muted),
                        ),
                        if (widget.earnedDate != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF30D66A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Đạt ngày: ${widget.earnedDate}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF30D66A),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Chọn nơi chia sẻ: Cộng đồng hoặc PT
            const Text(
              'Chọn kênh chia sẻ:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _shareTarget = 'community'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _shareTarget == 'community'
                            ? GymColors.purple.withValues(alpha: 0.2)
                            : GymColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _shareTarget == 'community'
                              ? GymColors.purple
                              : GymColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.public,
                            size: 18,
                            color: _shareTarget == 'community' ? GymColors.purple : GymColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Cộng đồng',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _shareTarget == 'community' ? Colors.white : GymColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _shareTarget = 'pt'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _shareTarget == 'pt'
                            ? GymColors.purple.withValues(alpha: 0.2)
                            : GymColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _shareTarget == 'pt'
                              ? GymColors.purple
                              : GymColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 18,
                            color: _shareTarget == 'pt' ? GymColors.purple : GymColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Gửi PT / Bạn tập',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _shareTarget == 'pt' ? Colors.white : GymColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Nếu chọn gửi PT, hiển thị dropdown chọn PT
            if (_shareTarget == 'pt') ...[
              const Text(
                'Gửi tới Huấn luyện viên / Bạn tập:',
                style: TextStyle(fontSize: 12, color: GymColors.muted),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: GymColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GymColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPt,
                    dropdownColor: GymColors.surface,
                    isExpanded: true,
                    items: _ptList.map((pt) {
                      return DropdownMenuItem<String>(
                        value: pt['name'],
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: GymColors.purple, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${pt['name']} (${pt['role']})',
                                style: const TextStyle(fontSize: 13, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedPt = val),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Nội dung bài viết
            const Text(
              'Nội dung chia sẻ:',
              style: TextStyle(fontSize: 12, color: GymColors.muted),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _contentCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: GymColors.surface,
                hintText: 'Nhập cảm nghĩ về thành tích này...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: GymColors.border),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Nút Xác nhận Chia sẻ
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GymColors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(_shareTarget == 'community' ? Icons.public : Icons.send_rounded),
                label: Text(
                  _loading
                      ? 'Đang chia sẻ...'
                      : (_shareTarget == 'community' ? 'Đăng Lên Cộng Đồng' : 'Gửi Cho $_selectedPt'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
