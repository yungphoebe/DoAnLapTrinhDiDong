import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../ui.dart';
import '../support/share_medal_sheet.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1. DATA MODELS
// ═════════════════════════════════════════════════════════════════════════════

class FriendUser {
  final String id;
  final String fullName;
  final String email;
  final String? trainingLevel;
  final String? goal;
  final int completedChallengesCount;
  final int wonDuelsCount;
  final int activeDuelsCount;
  final String status; // "Friend", "PendingIncoming", "PendingOutgoing", "None"
  final String? friendshipId;

  const FriendUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.trainingLevel,
    this.goal,
    required this.completedChallengesCount,
    required this.wonDuelsCount,
    required this.activeDuelsCount,
    required this.status,
    this.friendshipId,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Challenger',
      email: json['email']?.toString() ?? '',
      trainingLevel: json['trainingLevel']?.toString(),
      goal: json['goal']?.toString(),
      completedChallengesCount: (json['completedChallengesCount'] as num?)?.toInt() ?? 0,
      wonDuelsCount: (json['wonDuelsCount'] as num?)?.toInt() ?? 0,
      activeDuelsCount: (json['activeDuelsCount'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'None',
      friendshipId: json['friendshipId']?.toString(),
    );
  }
}

class FriendRequest {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String? trainingLevel;
  final bool isIncoming;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    this.trainingLevel,
    required this.isIncoming,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Người dùng',
      email: json['email']?.toString() ?? '',
      trainingLevel: json['trainingLevel']?.toString(),
      isIncoming: json['isIncoming'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class MedalModel {
  final String challengeId;
  final String challengeTitle;
  final String medalTitle;
  final String medalDescription;
  final String emoji;
  final String difficulty;
  final int points;
  final bool earned;
  final DateTime? earnedAt;
  final int currentProgress;
  final int totalSteps;
  final int completedSteps;

  const MedalModel({
    required this.challengeId,
    required this.challengeTitle,
    required this.medalTitle,
    required this.medalDescription,
    required this.emoji,
    required this.difficulty,
    required this.points,
    required this.earned,
    this.earnedAt,
    required this.currentProgress,
    required this.totalSteps,
    required this.completedSteps,
  });

  factory MedalModel.fromJson(Map<String, dynamic> json) {
    return MedalModel(
      challengeId: json['challengeId']?.toString() ?? '',
      challengeTitle: json['challengeTitle']?.toString() ?? '',
      medalTitle: json['medalTitle']?.toString() ?? '',
      medalDescription: json['medalDescription']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🏅',
      difficulty: json['difficulty']?.toString() ?? 'Medium',
      points: (json['points'] as num?)?.toInt() ?? 20,
      earned: json['earned'] == true,
      earnedAt: DateTime.tryParse(json['earnedAt']?.toString() ?? ''),
      currentProgress: (json['currentProgress'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
      completedSteps: (json['completedSteps'] as num?)?.toInt() ?? 0,
    );
  }
}

class MedalCompareItemModel {
  final String challengeId;
  final String challengeTitle;
  final String medalTitle;
  final String medalDescription;
  final String emoji;
  final String difficulty;
  final int points;
  final bool myEarned;
  final DateTime? myEarnedAt;
  final bool friendEarned;
  final DateTime? friendEarnedAt;

  const MedalCompareItemModel({
    required this.challengeId,
    required this.challengeTitle,
    required this.medalTitle,
    required this.medalDescription,
    required this.emoji,
    required this.difficulty,
    required this.points,
    required this.myEarned,
    this.myEarnedAt,
    required this.friendEarned,
    this.friendEarnedAt,
  });

  factory MedalCompareItemModel.fromJson(Map<String, dynamic> json) {
    return MedalCompareItemModel(
      challengeId: json['challengeId']?.toString() ?? '',
      challengeTitle: json['challengeTitle']?.toString() ?? '',
      medalTitle: json['medalTitle']?.toString() ?? '',
      medalDescription: json['medalDescription']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🏅',
      difficulty: json['difficulty']?.toString() ?? 'Medium',
      points: (json['points'] as num?)?.toInt() ?? 20,
      myEarned: json['myEarned'] == true,
      myEarnedAt: DateTime.tryParse(json['myEarnedAt']?.toString() ?? ''),
      friendEarned: json['friendEarned'] == true,
      friendEarnedAt: DateTime.tryParse(json['friendEarnedAt']?.toString() ?? ''),
    );
  }
}

class MedalCompareModel {
  final String myUserId;
  final String myName;
  final int myTotalPoints;
  final int myMedalsCount;
  final String friendUserId;
  final String friendName;
  final int friendTotalPoints;
  final int friendMedalsCount;
  final int totalAvailableMedals;
  final List<MedalCompareItemModel> items;

  const MedalCompareModel({
    required this.myUserId,
    required this.myName,
    required this.myTotalPoints,
    required this.myMedalsCount,
    required this.friendUserId,
    required this.friendName,
    required this.friendTotalPoints,
    required this.friendMedalsCount,
    required this.totalAvailableMedals,
    required this.items,
  });

  factory MedalCompareModel.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>?) ?? [];
    return MedalCompareModel(
      myUserId: json['myUserId']?.toString() ?? '',
      myName: json['myName']?.toString() ?? 'Tôi',
      myTotalPoints: (json['myTotalPoints'] as num?)?.toInt() ?? 0,
      myMedalsCount: (json['myMedalsCount'] as num?)?.toInt() ?? 0,
      friendUserId: json['friendUserId']?.toString() ?? '',
      friendName: json['friendName']?.toString() ?? 'Bạn bè',
      friendTotalPoints: (json['friendTotalPoints'] as num?)?.toInt() ?? 0,
      friendMedalsCount: (json['friendMedalsCount'] as num?)?.toInt() ?? 0,
      totalAvailableMedals: (json['totalAvailableMedals'] as num?)?.toInt() ?? 6,
      items: list.map((e) => MedalCompareItemModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class MedalLeaderboardUser {
  final int rank;
  final String userId;
  final String fullName;
  final String? trainingLevel;
  final int medalsCount;
  final int totalPoints;
  final bool isCurrentUser;
  final bool isFriend;

  const MedalLeaderboardUser({
    required this.rank,
    required this.userId,
    required this.fullName,
    this.trainingLevel,
    required this.medalsCount,
    required this.totalPoints,
    required this.isCurrentUser,
    required this.isFriend,
  });

  factory MedalLeaderboardUser.fromJson(Map<String, dynamic> json) {
    return MedalLeaderboardUser(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Challenger',
      trainingLevel: json['trainingLevel']?.toString(),
      medalsCount: (json['medalsCount'] as num?)?.toInt() ?? 0,
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      isCurrentUser: json['isCurrentUser'] == true,
      isFriend: json['isFriend'] == true,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. API SERVICE
// ═════════════════════════════════════════════════════════════════════════════

class SocialCompetitionService {
  SocialCompetitionService._();
  static final SocialCompetitionService instance = SocialCompetitionService._();

  Future<List<FriendUser>> getFriends() async {
    final res = await ApiClient.instance.get('/api/friends', includeAuth: true);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final List list = jsonDecode(res.body);
      return list.map((e) => FriendUser.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(res.statusCode, _extractMessage(res));
  }

  Future<List<FriendRequest>> getFriendRequests() async {
    final res = await ApiClient.instance.get('/api/friends/requests', includeAuth: true);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final List list = jsonDecode(res.body);
      return list.map((e) => FriendRequest.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(res.statusCode, _extractMessage(res));
  }

  Future<List<FriendUser>> searchUsers(String query) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final res = await ApiClient.instance.get('/api/friends/search?q=$encoded', includeAuth: true);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final List list = jsonDecode(res.body);
      return list.map((e) => FriendUser.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(res.statusCode, _extractMessage(res));
  }

  Future<String> sendFriendRequest(String targetUserId) async {
    final res = await ApiClient.instance.post(
      '/api/friends/request',
      {'targetUserId': targetUserId},
      includeAuth: true,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return data['message']?.toString() ?? 'Đã gửi lời mời!';
    }
    throw ApiException(res.statusCode, _extractMessage(res));
  }

  Future<String> acceptFriendRequest(String requestId) async {
    final res = await ApiClient.instance.post(
      '/api/friends/requests/$requestId/accept',
      {},
      includeAuth: true,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return data['message']?.toString() ?? 'Đã chấp nhận!';
    }
    throw ApiException(res.statusCode, _extractMessage(res));
  }

  Future<String> declineFriendRequest(String requestId) async {
    final res = await ApiClient.instance.post(
      '/api/friends/requests/$requestId/decline',
      {},
      includeAuth: true,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return data['message']?.toString() ?? 'Đã từ chối.';
    }
    throw ApiException(res.statusCode, _extractMessage(res));
  }

  Future<String> unfriend(String friendUserId) async {
    final res = await ApiClient.instance.delete(
      '/api/friends/$friendUserId',
      includeAuth: true,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return data['message']?.toString() ?? 'Đã hủy kết bạn.';
    }
    throw ApiException(res.statusCode, _extractMessage(res));
  }

  Future<List<MedalModel>> getMyMedals() async {
    final res = await ApiClient.instance.get('/api/medals/my', includeAuth: true);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final List list = jsonDecode(res.body);
      return list.map((e) => MedalModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(res.statusCode, _extractMessage(res));
  }

  Future<MedalCompareModel> compareMedals(String friendId) async {
    final res = await ApiClient.instance.get('/api/medals/compare/$friendId', includeAuth: true);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return MedalCompareModel.fromJson(data as Map<String, dynamic>);
    }
    throw ApiException(res.statusCode, _extractMessage(res));
  }

  Future<List<MedalLeaderboardUser>> getMedalLeaderboard({bool friendsOnly = false}) async {
    final scope = friendsOnly ? 'friends' : 'all';
    final res = await ApiClient.instance.get('/api/medals/leaderboard?scope=$scope', includeAuth: true);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final List list = jsonDecode(res.body);
      return list.map((e) => MedalLeaderboardUser.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(res.statusCode, _extractMessage(res));
  }

  String _extractMessage(dynamic res) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return 'Lỗi máy chủ (${res.statusCode})';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. UI SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class FriendsCompetitionScreen extends StatefulWidget {
  const FriendsCompetitionScreen({super.key});

  @override
  State<FriendsCompetitionScreen> createState() => _FriendsCompetitionScreenState();
}

class _FriendsCompetitionScreenState extends State<FriendsCompetitionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final SocialCompetitionService _service = SocialCompetitionService.instance;

  bool _loading = false;
  List<FriendUser> _friends = [];
  List<FriendRequest> _requests = [];

  // Medals state
  List<MedalModel> _myMedals = [];
  FriendUser? _selectedCompareFriend;
  MedalCompareModel? _compareData;
  bool _loadingCompare = false;
  List<MedalLeaderboardUser> _medalLeaderboard = [];
  bool _medalLeaderboardFriendsOnly = true;
  int _medalSubTab = 0; // 0: So Sánh, 1: Bộ Sưu Tập, 2: BXH

  // Search tab
  final TextEditingController _searchCtrl = TextEditingController();
  List<FriendUser> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getFriends(),
        _service.getFriendRequests(),
        _service.getMyMedals(),
        _service.getMedalLeaderboard(friendsOnly: _medalLeaderboardFriendsOnly),
      ]);

      if (mounted) {
        final friends = results[0] as List<FriendUser>;
        setState(() {
          _friends = friends;
          _requests = results[1] as List<FriendRequest>;
          _myMedals = results[2] as List<MedalModel>;
          _medalLeaderboard = results[3] as List<MedalLeaderboardUser>;
          _loading = false;
        });

        if (friends.isNotEmpty) {
          if (_selectedCompareFriend == null) {
            _selectCompareFriend(friends.first);
          } else {
            final exists = friends.any((f) => f.id == _selectedCompareFriend!.id);
            if (exists) {
              _selectCompareFriend(_selectedCompareFriend!);
            } else {
              _selectCompareFriend(friends.first);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnackBar('Lỗi tải dữ liệu: $e');
      }
    }
  }

  Future<void> _selectCompareFriend(FriendUser friend) async {
    setState(() {
      _selectedCompareFriend = friend;
      _loadingCompare = true;
    });
    try {
      final data = await _service.compareMedals(friend.id);
      if (mounted) {
        setState(() {
          _compareData = data;
          _loadingCompare = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCompare = false);
        _showSnackBar('Lỗi tải dữ liệu so sánh: $e');
      }
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? GymColors.green : const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ──────────────────────── FRIEND ACTIONS ────────────────────────

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      final msg = await _service.acceptFriendRequest(requestId);
      _showSnackBar(msg, isSuccess: true);
      _loadAllData();
    } catch (e) {
      _showSnackBar('Lỗi: $e');
    }
  }

  Future<void> _declineFriendRequest(String requestId) async {
    try {
      final msg = await _service.declineFriendRequest(requestId);
      _showSnackBar(msg);
      _loadAllData();
    } catch (e) {
      _showSnackBar('Lỗi: $e');
    }
  }

  Future<void> _unfriend(String friendId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GymColors.surface,
        title: const Text('Xác nhận hủy kết bạn', style: TextStyle(color: Colors.white)),
        content: Text('Bạn có chắc chắn muốn hủy kết bạn với $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: GymColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đồng ý', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final msg = await _service.unfriend(friendId);
        _showSnackBar(msg);
        _loadAllData();
      } catch (e) {
        _showSnackBar('Lỗi: $e');
      }
    }
  }

  // ──────────────────────── SEARCH ACTIONS ────────────────────────

  Future<void> _searchUsers() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final list = await _service.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = list;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        _showSnackBar('Lỗi tìm kiếm: $e');
      }
    }
  }

  Future<void> _sendFriendRequest(FriendUser user) async {
    try {
      final msg = await _service.sendFriendRequest(user.id);
      _showSnackBar(msg, isSuccess: true);
      _searchUsers();
      _loadAllData();
    } catch (e) {
      _showSnackBar('Lỗi: $e');
    }
  }

  // ──────────────────────── BUILD UI ────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymColors.background,
      appBar: AppBar(
        leading: CircleBackButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
        title: const Text('Thi Đua Huy Chương & Bạn Bè'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: GymColors.purple,
          labelColor: GymColors.purple,
          unselectedLabelColor: GymColors.muted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            Tab(
              icon: const Icon(Icons.military_tech, size: 20),
              text: 'Huy Chương (${_myMedals.where((m) => m.earned).length})',
            ),
            Tab(
              icon: const Icon(Icons.people_alt, size: 20),
              text: 'Bạn Bè (${_friends.length})',
            ),
            const Tab(
              icon: Icon(Icons.person_add_alt_1, size: 20),
              text: 'Tìm Bạn',
            ),
          ],
        ),
      ),
      body: _loading && _friends.isEmpty && _myMedals.isEmpty
          ? const Center(child: CircularProgressIndicator(color: GymColors.purple))
          : Column(
              children: [
                _buildTopStatsBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMedalsTab(),
                      _buildFriendsTab(),
                      _buildSearchTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopStatsBanner() {
    final earnedMedalsCount = _myMedals.where((m) => m.earned).length;
    final myTotalPoints = _myMedals.where((m) => m.earned).fold<int>(0, (s, m) => s + m.points);
    final myRankIndex = _medalLeaderboard.indexWhere((u) => u.isCurrentUser);
    final myRank = myRankIndex >= 0 ? _medalLeaderboard[myRankIndex].rank : 1;

    return Container(
      color: GymColors.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.people_outline,
            label: 'Bạn bè',
            value: '${_friends.length}',
            color: const Color(0xFF38BDF8),
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.military_tech,
            label: 'Huy chương',
            value: '$earnedMedalsCount/${_myMedals.isNotEmpty ? _myMedals.length : 6}',
            color: const Color(0xFFFFD700),
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.stars,
            label: 'Danh dự',
            value: '$myTotalPoints pts',
            color: GymColors.purple,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: _requests.isNotEmpty ? Icons.mail_outline : Icons.leaderboard_outlined,
            label: _requests.isNotEmpty ? 'Lời mời' : 'Thứ hạng',
            value: _requests.isNotEmpty ? '${_requests.length}' : '#$myRank',
            color: const Color(0xFFFACC15),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: GymColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: GymColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: GymColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: GymColors.purple),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  // ════════════════════════ TAB 2: FRIENDS ════════════════════════

  Widget _buildFriendsTab() {
    return RefreshIndicator(
      color: GymColors.purple,
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          if (_requests.where((r) => r.isIncoming).isNotEmpty) ...[
            _buildSectionHeader('Lời Mời Kết Bạn Mới', Icons.person_add),
            const SizedBox(height: 10),
            ..._requests.where((r) => r.isIncoming).map((req) => _buildIncomingRequestCard(req)),
            const SizedBox(height: 20),
          ],

          _buildSectionHeader('Danh Sách Bạn Bè (${_friends.length})', Icons.people),
          const SizedBox(height: 10),

          if (_friends.isEmpty)
            _buildEmptyCard(
              'Chưa có bạn bè nào',
              'Hãy chuyển sang tab "Tìm Bạn" để kết nối cùng các gymer khác!',
              actionLabel: 'Tìm Bạn Ngay',
              onAction: () => _tabController.animateTo(2),
            )
          else
            ..._friends.map((friend) => _buildFriendCard(friend)),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestCard(FriendRequest req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GymColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GymColors.purple.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: GymColors.purple.withValues(alpha: 0.3),
            child: Text(
              req.fullName.isNotEmpty ? req.fullName[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Text(req.email, style: const TextStyle(fontSize: 11, color: GymColors.muted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            onPressed: () => _declineFriendRequest(req.id),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: GymColors.green, size: 22),
            onPressed: () => _acceptFriendRequest(req.id),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(FriendUser friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GymColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GymColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: GymColors.purple.withValues(alpha: 0.25),
            child: Text(
              friend.fullName.isNotEmpty ? friend.fullName[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  '${friend.completedChallengesCount} huy chương đã đạt',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFFFD700)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GymColors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.military_tech, size: 16),
            label: const Text('So Sánh HC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              _selectCompareFriend(friend);
              setState(() => _medalSubTab = 0);
              _tabController.animateTo(0);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: GymColors.muted),
            color: GymColors.surface,
            onSelected: (val) {
              if (val == 'unfriend') {
                _unfriend(friend.id, friend.fullName);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'unfriend',
                child: Text('Hủy kết bạn', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════ TAB 3: SEARCH FRIENDS ════════════════════════

  Widget _buildSearchTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _buildSectionHeader('Tìm Kiếm Bạn Tập Mới', Icons.search),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchUsers(),
                decoration: InputDecoration(
                  hintText: 'Nhập tên hoặc email bạn bè...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GymColors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _searchUsers,
                child: const Text('Tìm'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_isSearching)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: GymColors.purple),
          ))
        else if (_searchResults.isNotEmpty) ...[
          Text('Kết quả tìm kiếm (${_searchResults.length}):', style: const TextStyle(color: GymColors.muted)),
          const SizedBox(height: 10),
          ..._searchResults.map((user) => _buildSearchResultCard(user)),
        ] else if (_searchCtrl.text.trim().isNotEmpty) ...[
          _buildEmptyCard('Không tìm thấy ai phù hợp', 'Hãy thử tìm bằng email hoặc từ khóa khác nhé!')
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GymColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GymColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Color(0xFFFACC15), size: 20),
                    SizedBox(width: 8),
                    Text('Mẹo kết bạn:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                SizedBox(height: 8),
                Text('• Tìm bạn bè qua địa chỉ email hoặc tên đầy đủ khi đăng ký tài khoản.', style: TextStyle(fontSize: 12, color: GymColors.muted)),
                SizedBox(height: 4),
                Text('• Kết bạn để cùng nhau tham gia các thử thách Gym và thi đua xem ai hoàn thành mục tiêu trước!', style: TextStyle(fontSize: 12, color: GymColors.muted)),
                SizedBox(height: 4),
                Text('• Điểm chiến binh tích lũy sẽ giúp bạn thăng hạng trên Bảng Xếp Hạng Challenger!', style: TextStyle(fontSize: 12, color: GymColors.muted)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchResultCard(FriendUser user) {
    Widget actionWidget;
    if (user.status == 'Friend') {
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: GymColors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Bạn bè', style: TextStyle(fontSize: 12, color: GymColors.green, fontWeight: FontWeight.bold)),
      );
    } else if (user.status == 'PendingOutgoing') {
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Đã gửi lời mời', style: TextStyle(fontSize: 12, color: Colors.amber)),
      );
    } else if (user.status == 'PendingIncoming') {
      actionWidget = ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: GymColors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          if (user.friendshipId != null) {
            _acceptFriendRequest(user.friendshipId!);
          }
        },
        child: const Text('Đồng ý', style: TextStyle(fontSize: 12)),
      );
    } else {
      actionWidget = ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: GymColors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.person_add, size: 16),
        label: const Text('Kết bạn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        onPressed: () => _sendFriendRequest(user),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GymColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GymColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: GymColors.purple.withValues(alpha: 0.25),
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Text(user.email, style: const TextStyle(fontSize: 11, color: GymColors.muted)),
              ],
            ),
          ),
          actionWidget,
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String title, String subtitle, {String? actionLabel, VoidCallback? onAction}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: GymColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GymColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.sports_score, size: 40, color: GymColors.muted),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: GymColors.muted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GymColors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════ TAB 0: MEDAL COMPETITION & COMPARISON ════════════════════════

  Widget _buildMedalsTab() {
    return RefreshIndicator(
      color: GymColors.purple,
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: GymColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GymColors.border),
            ),
            child: Row(
              children: [
                _buildSubTabButton(0, 'So Sánh Bạn Bè', Icons.compare_arrows),
                _buildSubTabButton(1, 'Bộ Sưu Tập', Icons.military_tech),
                _buildSubTabButton(2, 'BXH Huy Chương', Icons.leaderboard),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_medalSubTab == 0)
            _buildMedalCompareSubTab()
          else if (_medalSubTab == 1)
            _buildMyMedalsSubTab()
          else
            _buildMedalLeaderboardSubTab(),
        ],
      ),
    );
  }

  Widget _buildSubTabButton(int index, String title, IconData icon) {
    final isSelected = _medalSubTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _medalSubTab = index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? GymColors.purple : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : GymColors.muted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : GymColors.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedalCompareSubTab() {
    if (_friends.isEmpty) {
      return _buildEmptyCard(
        'Chưa có bạn bè để so sánh huy chương',
        'Hãy kết bạn với những người tập cùng để so tài số huy chương và điểm thành tích!',
        actionLabel: 'Tìm Bạn Ngay',
        onAction: () => _tabController.animateTo(2),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: GymColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GymColors.purple.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_search, color: GymColors.purple, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Đối thủ:',
                style: TextStyle(fontSize: 13, color: GymColors.muted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCompareFriend?.id,
                    isExpanded: true,
                    dropdownColor: GymColors.surface,
                    hint: const Text('Chọn bạn bè...', style: TextStyle(color: GymColors.muted, fontSize: 13)),
                    items: _friends.map((f) {
                      return DropdownMenuItem(
                        value: f.id,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: GymColors.purple.withValues(alpha: 0.3),
                              child: Text(
                                f.fullName.isNotEmpty ? f.fullName[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f.fullName,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${f.completedChallengesCount} HC',
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        final friend = _friends.firstWhere((f) => f.id == id);
                        _selectCompareFriend(friend);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_loadingCompare)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: GymColors.purple)),
          )
        else if (_compareData != null) ...[
          _buildScoreComparisonCard(_compareData!),
          const SizedBox(height: 20),
          _buildSectionHeader('Bảng So Sánh 6 Huy Chương', Icons.military_tech),
          const SizedBox(height: 10),
          ..._compareData!.items.map((item) => _buildMedalCompareItemCard(item)),
        ] else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Vui lòng chọn 1 người bạn để bắt đầu so sánh huy chương!', style: TextStyle(color: GymColors.muted)),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreComparisonCard(MedalCompareModel data) {
    final isAhead = data.myTotalPoints > data.friendTotalPoints;
    final isBehind = data.myTotalPoints < data.friendTotalPoints;
    final diffPoints = (data.myTotalPoints - data.friendTotalPoints).abs();

    final totalPointsSum = data.myTotalPoints + data.friendTotalPoints;
    final myRatio = totalPointsSum > 0 ? (data.myTotalPoints / totalPointsSum) : 0.5;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GymColors.purple.withValues(alpha: 0.25),
            GymColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAhead ? GymColors.purple : (isBehind ? const Color(0xFFFACC15) : GymColors.border),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: GymColors.purple.withValues(alpha: 0.35),
                          child: const Icon(Icons.person, color: Colors.white, size: 28),
                        ),
                        if (isAhead)
                          const Positioned(
                            top: -6,
                            right: -6,
                            child: Text('👑', style: TextStyle(fontSize: 16)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.myName,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: GymColors.purple.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${data.myTotalPoints} pts',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${data.myMedalsCount}/${data.totalAvailableMedals} huy chương',
                      style: const TextStyle(color: GymColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: GymColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GymColors.border),
                      ),
                      child: const Text(
                        'VS',
                        style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD700), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAhead
                            ? GymColors.green.withValues(alpha: 0.15)
                            : (isBehind ? const Color(0xFFFACC15).withValues(alpha: 0.15) : GymColors.purple.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAhead
                            ? 'Bạn dẫn +$diffPoints'
                            : (isBehind ? 'Kém -$diffPoints' : 'Đang hòa!'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isAhead ? GymColors.green : (isBehind ? const Color(0xFFFACC15) : Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                          child: Text(
                            data.friendName.isNotEmpty ? data.friendName[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), fontSize: 20),
                          ),
                        ),
                        if (isBehind)
                          const Positioned(
                            top: -6,
                            right: -6,
                            child: Text('👑', style: TextStyle(fontSize: 16)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.friendName,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${data.friendTotalPoints} pts',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${data.friendMedalsCount}/${data.totalAvailableMedals} huy chương',
                      style: const TextStyle(color: GymColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (myRatio * 100).round().clamp(1, 99),
                    child: Container(color: GymColors.purple),
                  ),
                  Expanded(
                    flex: ((1 - myRatio) * 100).round().clamp(1, 99),
                    child: Container(color: const Color(0xFF38BDF8)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(myRatio * 100).round()}% thế trận của bạn', style: const TextStyle(fontSize: 10, color: GymColors.muted)),
              Text('${((1 - myRatio) * 100).round()}% của đối thủ', style: const TextStyle(fontSize: 10, color: GymColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedalCompareItemCard(MedalCompareItemModel item) {
    Color difficultyColor;
    String difficultyLabel;
    switch (item.difficulty.toLowerCase()) {
      case 'easy':
        difficultyColor = GymColors.green;
        difficultyLabel = 'Dễ (${item.points} pts)';
        break;
      case 'hard':
        difficultyColor = const Color(0xFFFF4F6D);
        difficultyLabel = 'Khó (${item.points} pts)';
        break;
      default:
        difficultyColor = const Color(0xFFFFB83F);
        difficultyLabel = 'Vừa (${item.points} pts)';
        break;
    }

    String advantageNote;
    Color advantageColor;
    if (item.myEarned && !item.friendEarned) {
      advantageNote = '🔥 Bạn đang dẫn trước ở huy chương này (+${item.points} pts)';
      advantageColor = GymColors.purple;
    } else if (!item.myEarned && item.friendEarned) {
      advantageNote = '⚠️ Đối thủ đã chinh phục! Cố lên để san bằng điểm!';
      advantageColor = const Color(0xFFFFB83F);
    } else if (item.myEarned && item.friendEarned) {
      advantageNote = '⭐ Cả hai cùng là chiến binh chinh phục thành công!';
      advantageColor = GymColors.green;
    } else {
      advantageNote = '⏳ Chưa ai đạt — Cơ hội bứt phá dành cho bạn!';
      advantageColor = GymColors.muted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GymColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.myEarned
              ? GymColors.purple.withValues(alpha: 0.6)
              : GymColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.medalTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    Text(
                      item.challengeTitle,
                      style: const TextStyle(fontSize: 11, color: GymColors.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: difficultyColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  difficultyLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: difficultyColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.myEarned
                        ? GymColors.purple.withValues(alpha: 0.12)
                        : GymColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.myEarned
                          ? GymColors.purple.withValues(alpha: 0.5)
                          : GymColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tôi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            item.myEarned ? Icons.check_circle : Icons.lock_outline,
                            size: 15,
                            color: item.myEarned ? GymColors.green : GymColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.myEarned ? 'Đã đạt' : 'Chưa đạt',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: item.myEarned ? GymColors.green : GymColors.muted,
                            ),
                          ),
                        ],
                      ),
                      if (item.myEarned && item.myEarnedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(item.myEarnedAt),
                          style: const TextStyle(fontSize: 10, color: GymColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.friendEarned
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.12)
                        : GymColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.friendEarned
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                          : GymColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _compareData?.friendName ?? 'Bạn bè',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            item.friendEarned ? Icons.check_circle : Icons.lock_outline,
                            size: 15,
                            color: item.friendEarned ? const Color(0xFF38BDF8) : GymColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.friendEarned ? 'Đã đạt' : 'Chưa đạt',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: item.friendEarned ? const Color(0xFF38BDF8) : GymColors.muted,
                            ),
                          ),
                        ],
                      ),
                      if (item.friendEarned && item.friendEarnedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(item.friendEarnedAt),
                          style: const TextStyle(fontSize: 10, color: GymColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: GymColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              advantageNote,
              style: TextStyle(fontSize: 11, color: advantageColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyMedalsSubTab() {
    final earnedList = _myMedals.where((m) => m.earned).toList();
    final totalPoints = earnedList.fold<int>(0, (s, m) => s + m.points);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                GymColors.purple.withValues(alpha: 0.25),
                GymColors.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GymColors.purple.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bộ Sưu Tập Huy Chương', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      'Đã mở khóa: ${earnedList.length} / ${_myMedals.length} huy chương',
                      style: const TextStyle(fontSize: 12, color: GymColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$totalPoints Điểm Danh Dự',
                            style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildSectionHeader('Tất Cả Huy Chương (${_myMedals.length})', Icons.military_tech_outlined),
        const SizedBox(height: 10),

        if (_myMedals.isEmpty)
          const Center(child: CircularProgressIndicator(color: GymColors.purple))
        else
          ..._myMedals.map((medal) => _buildSingleMedalCard(medal)),
      ],
    );
  }

  Widget _buildSingleMedalCard(MedalModel medal) {
    Color difficultyColor;
    switch (medal.difficulty.toLowerCase()) {
      case 'easy':
        difficultyColor = GymColors.green;
        break;
      case 'hard':
        difficultyColor = const Color(0xFFFF4F6D);
        break;
      default:
        difficultyColor = const Color(0xFFFFB83F);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GymColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: medal.earned ? const Color(0xFFFFD700) : GymColors.border,
          width: medal.earned ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: medal.earned ? const Color(0xFFFFD700).withValues(alpha: 0.15) : GymColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              medal.emoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        medal.medalTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: medal.earned ? Colors.white : GymColors.muted,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: difficultyColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${medal.points} pts',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: difficultyColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  medal.medalDescription,
                  style: const TextStyle(fontSize: 12, color: GymColors.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            medal.earned ? Icons.verified : Icons.lock_outline,
                            size: 14,
                            color: medal.earned ? GymColors.green : GymColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              medal.earned
                                  ? (medal.earnedAt != null
                                      ? 'Đã đạt ngày ${_formatDate(medal.earnedAt)}'
                                      : 'Đã hoàn thành!')
                                  : 'Chưa mở khóa (${medal.completedSteps}/${medal.totalSteps} bước)',
                              style: TextStyle(
                                fontSize: 11,
                                color: medal.earned ? GymColors.green : GymColors.muted,
                                fontWeight: medal.earned ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (medal.earned) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => ShareMedalSheet.show(
                          context: context,
                          medalTitle: medal.medalTitle,
                          medalDescription: medal.medalDescription,
                          emoji: medal.emoji,
                          color: const Color(0xFFFFD700),
                          earnedDate: medal.earnedAt != null ? _formatDate(medal.earnedAt) : null,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: GymColors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: GymColors.purple.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.share_rounded, size: 11, color: GymColors.purple),
                              SizedBox(width: 4),
                              Text(
                                'Chia sẻ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedalLeaderboardSubTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('BXH Điểm Huy Chương', Icons.military_tech),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Bạn Bè', style: TextStyle(fontSize: 11)),
                  selected: _medalLeaderboardFriendsOnly,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _medalLeaderboardFriendsOnly = true);
                      _service.getMedalLeaderboard(friendsOnly: true).then((list) {
                        if (mounted) setState(() => _medalLeaderboard = list);
                      });
                    }
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Toàn Cầu', style: TextStyle(fontSize: 11)),
                  selected: !_medalLeaderboardFriendsOnly,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _medalLeaderboardFriendsOnly = false);
                      _service.getMedalLeaderboard(friendsOnly: false).then((list) {
                        if (mounted) setState(() => _medalLeaderboard = list);
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_medalLeaderboard.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Chưa có dữ liệu bảng xếp hạng', style: TextStyle(color: GymColors.muted)),
            ),
          )
        else
          ..._medalLeaderboard.map((user) => _buildMedalLeaderboardUserRow(user)),
      ],
    );
  }

  Widget _buildMedalLeaderboardUserRow(MedalLeaderboardUser user) {
    Widget rankWidget;
    Color? rankBorderColor;
    if (user.rank == 1) {
      rankWidget = const Text('🥇', style: TextStyle(fontSize: 20));
      rankBorderColor = const Color(0xFFFFD700);
    } else if (user.rank == 2) {
      rankWidget = const Text('🥈', style: TextStyle(fontSize: 20));
      rankBorderColor = const Color(0xFFC0C0C0);
    } else if (user.rank == 3) {
      rankWidget = const Text('🥉', style: TextStyle(fontSize: 20));
      rankBorderColor = const Color(0xFFCD7F32);
    } else {
      rankWidget = Text(
        '#${user.rank}',
        style: const TextStyle(fontWeight: FontWeight.bold, color: GymColors.muted, fontSize: 13),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: user.isCurrentUser
            ? GymColors.purple.withValues(alpha: 0.15)
            : GymColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isCurrentUser
              ? GymColors.purple
              : (rankBorderColor ?? GymColors.border),
          width: user.isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Center(child: rankWidget)),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: user.isCurrentUser
                ? GymColors.purple
                : const Color(0xFF38BDF8).withValues(alpha: 0.25),
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: GymColors.purple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Bạn', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text(
                  user.trainingLevel ?? 'Challenger',
                  style: const TextStyle(fontSize: 10, color: GymColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user.totalPoints} pts',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFD700), fontSize: 13),
              ),
              Text(
                '${user.medalsCount} huy chương 🏅',
                style: const TextStyle(fontSize: 10, color: GymColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
