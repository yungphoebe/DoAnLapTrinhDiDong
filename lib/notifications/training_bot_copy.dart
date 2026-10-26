String trainingBotMessage(Map<String, dynamic>? profile, {bool roast = false}) {
  if (profile == null) {
    return 'Chưa có dữ liệu tập hôm nay. Tải lại hồ sơ để bot nhắc đúng tiến độ nhé!';
  }
  final seconds = (profile['todayWorkoutSeconds'] as num?)?.toInt() ?? 0;
  final streak = (profile['streakDays'] as num?)?.toInt() ?? 0;
  if (seconds > 0) {
    final duration = seconds < 60 ? '$seconds giây' : '${seconds ~/ 60} phút';
    return 'Hôm nay bạn đã tập $duration! '
        '${roast ? 'Được đấy, nói là làm! ' : 'Mỗi bước nhỏ đều đáng ghi nhận. '}'
        '${streak > 0 ? 'Chuỗi hiện tại: $streak ngày. ' : ''}'
        'Nghỉ ngơi và hồi phục nhé.';
  }
  return '${streak > 0 ? 'Bạn đang có chuỗi $streak ngày. ' : ''}'
      '${roast ? 'Đừng để chiếc ghế thắng bạn! Lướt điện thoại đủ rồi, dậy tập 5 phút coi.' : 'Nếu hôm nay là ngày tập, bắt đầu với 5 phút nhé. Bot luôn cổ vũ bạn!'}';
}

// shortcut: recurring Android notifications cannot read live progress; use conditional copy until delivery-time background sync exists.
String scheduledWorkoutMessage({required bool roast}) => roast
    ? 'Nếu chưa tập thì đừng để chiếc ghế thắng bạn! Dậy vận động 5 phút nào. Tập rồi thì nghỉ khỏe nhé!'
    : 'Đến giờ vận động! Nếu chưa tập, bắt đầu với 5 phút nhé. Tập rồi thì dành thời gian hồi phục.';
