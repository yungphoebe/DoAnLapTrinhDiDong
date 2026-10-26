import 'package:flutter/material.dart';

import '../controllers/post_controller.dart';
import '../models/post.dart';
import '../services/post_api.dart';
import '../ui.dart';

enum _FinderProfileType { trainer, partner }

class _FinderProfile {
  const _FinderProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.goals,
    required this.summary,
    required this.availability,
    required this.details,
    required this.avatarAsset,
  });

  final String id;
  final String name;
  final _FinderProfileType type;
  final String city;
  final List<String> goals;
  final String summary;
  final String availability;
  final String details;
  final String avatarAsset;

  String get typeLabel => type == _FinderProfileType.trainer ? 'PT' : 'Ban tap';

  String get profileTitle =>
      type == _FinderProfileType.trainer ? 'Ho so PT' : 'Ho so ban tap';
}

const _finderProfiles = [
  _FinderProfile(
    id: 'hai-dang',
    name: 'HLV. Hai Dang',
    type: _FinderProfileType.trainer,
    city: 'Ha Noi',
    goals: ['Giam can', 'Tang co'],
    summary: 'Chuyen mon: Dot mo & Tang co',
    availability: 'Lich ranh: Sang / Toi',
    details: 'Huan luyen ca nhan theo muc tieu, muc the luc va thoi gian tap cua hoc vien.',
    avatarAsset: 'assets/images/trainer.jpg',
  ),
  _FinderProfile(
    id: 'minh-anh',
    name: 'Minh Anh',
    type: _FinderProfileType.partner,
    city: 'Ha Noi',
    goals: ['Giam can', 'Giu dang'],
    summary: 'Tim ban tap cardio va meal prep',
    availability: 'Lich ranh: Toi thu 2/4/6',
    details:
        'Muon co ban dong hanh tap deu, chia se lich an va nhac nhau check-in.',
    avatarAsset: 'assets/images/avatar.jpg',
  ),
  _FinderProfile(
    id: 'quoc-bao',
    name: 'Quoc Bao',
    type: _FinderProfileType.partner,
    city: 'Da Nang',
    goals: ['Tang co'],
    summary: 'Tim ban tap gym tu do',
    availability: 'Lich ranh: Chieu / Cuoi tuan',
    details: 'Dang theo lich tang co 4 buoi moi tuan, uu tien tap cung nguoi co muc tieu gan nhau.',
    avatarAsset: 'assets/images/community.jpg',
  ),
  _FinderProfile(
    id: 'thu-ha',
    name: 'PT Thu Ha',
    type: _FinderProfileType.trainer,
    city: 'TP. Ho Chi Minh',
    goals: ['Giu dang', 'Giam can'],
    summary: 'Chuyen mon: Mobility & Giu dang',
    availability: 'Lich ranh: Trua / Toi',
    details: 'Thiet ke giao an nhe nha, tap trung ky thuat dong tac va thoi quen ben vung.',
    avatarAsset: 'assets/images/trainer.jpg',
  ),
];

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.controller});

  final PostController? controller;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late final PostController _postController;
  late final bool _ownsController;
  var _tab = 0;
  final _requestedProfileIds = <String>{};
  var _city = 'Ha Noi';
  var _goal = 'Giam can';

  List<_FinderProfile> get _visibleProfiles => _finderProfiles
      .where(
        (profile) => profile.city == _city && profile.goals.contains(_goal),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _postController = widget.controller ?? PostController(api: PostApi());
    _postController.loadPosts();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _postController.dispose();
    }
    super.dispose();
  }

  void _filters() {
    var city = _city;
    var goal = _goal;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tim nguoi cung muc tieu',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Thanh pho',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final value in [
                      'Ha Noi',
                      'TP. Ho Chi Minh',
                      'Da Nang',
                    ])
                      ChoiceChip(
                        label: Text(value),
                        selected: city == value,
                        onSelected: (_) => updateSheet(() => city = value),
                      ),
                  ],
                ),
                const SizedBox(height: 15),
                const Text(
                  'Muc tieu',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final value in ['Giam can', 'Tang co', 'Giu dang'])
                      ChoiceChip(
                        label: Text(value),
                        selected: goal == value,
                        onSelected: (_) => updateSheet(() => goal = value),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Bo loc ap dung cho du lieu minh hoa.',
                  style: TextStyle(color: GymColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Ap dung',
                  onPressed: () {
                    setState(() {
                      _city = city;
                      _goal = goal;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPostForm({Post? post}) {
    final input = TextEditingController(text: post?.content ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  post == null ? 'Tao bai dang' : 'Sua bai dang',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('post-content-input'),
                  controller: input,
                  minLines: 3,
                  maxLines: 5,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Ban dang nghi gi ve buoi tap hom nay?',
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  key: const Key('save-post'),
                  label: post == null ? 'Dang bai' : 'Luu thay doi',
                  onPressed: () async {
                    final saved = post == null
                        ? await _postController.createPost(input.text)
                        : await _postController.updatePost(post.id, input.text);
                    if (!context.mounted) return;
                    if (saved) {
                      Navigator.pop(context);
                    } else {
                      showMessage(context, 'Vui long nhap noi dung bai viet');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPostActions(Post post) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: Key('edit-post-${post.id}'),
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Sua bai dang'),
                onTap: () {
                  Navigator.pop(context);
                  _openPostForm(post: post);
                },
              ),
              ListTile(
                key: Key('delete-post-${post.id}'),
                leading: const Icon(Icons.delete_outline),
                title: const Text('Xoa bai dang'),
                textColor: Colors.redAccent,
                iconColor: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(post);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Post post) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoa bai dang?'),
        content: const Text('Bai dang se bien mat khoi bang tin minh hoa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huy'),
          ),
          FilledButton(
            key: const Key('confirm-delete-post'),
            onPressed: () async {
              await _postController.deletePost(post.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Xoa'),
          ),
        ],
      ),
    );
  }

  void _openComments(Post post) {
    final input = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) {
          Future<void> addComment() async {
            final added = await _postController.addComment(post.id, input.text);
            if (!added) return;
            input.clear();
            updateSheet(() {});
          }

          final currentPost = _postController.posts.firstWhere(
            (item) => item.id == post.id,
            orElse: () => post,
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .56,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Binh luan',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Dong binh luan',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Text(
                        'Binh luan luu qua PostController trong phien demo.',
                        style: TextStyle(fontSize: 11, color: GymColors.muted),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final comment in currentPost.comments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 17),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comment.authorName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      comment.content,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('comment-input'),
                              controller: input,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => addComment(),
                              decoration: const InputDecoration(
                                hintText: 'Viet binh luan...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            key: const Key('comment-send'),
                            tooltip: 'Gui binh luan',
                            onPressed: addComment,
                            icon: const Icon(Icons.arrow_upward),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _profile(_FinderProfile profile) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                profile.avatarAsset,
                height: 210,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              profile.profileTitle,
              style: const TextStyle(
                fontSize: 13,
                color: GymColors.purple,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              [
                'Loai ho so: ${profile.typeLabel}',
                'Thanh pho: ${profile.city}',
                'Muc tieu: ${profile.goals.join(', ')}',
                profile.availability,
                profile.summary,
                profile.details,
              ].join('\n'),
              style: const TextStyle(height: 1.8),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Dong ho so',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _tag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF28252E),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 10, color: GymColors.muted),
    ),
  );

  Widget _profileCard(_FinderProfile profile) {
    final requested = _requestedProfileIds.contains(profile.id);
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 29,
                backgroundImage: AssetImage(profile.avatarAsset),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF352042),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            profile.typeLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: GymColors.purple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.summary,
                      style: const TextStyle(
                        fontSize: 11,
                        color: GymColors.muted,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      profile.city,
                      style: const TextStyle(
                        fontSize: 11,
                        color: GymColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _tag(profile.availability),
              for (final goal in profile.goals) _tag(goal),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _profile(profile),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 41),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'Xem ho so',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() {
                    if (requested) {
                      _requestedProfileIds.remove(profile.id);
                    } else {
                      _requestedProfileIds.add(profile.id);
                    }
                  }),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 41),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Text(
                    requested ? 'Da gui loi moi' : 'Ket noi ngay',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            requested
                ? 'Loi moi minh hoa - cham lai de huy.'
                : 'Ket noi minh hoa, chi luu tren thiet bi.',
            style: const TextStyle(fontSize: 9, color: GymColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _finder() {
    final profiles = _visibleProfiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Cung nhau tien bo moi ngay',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Ket qua tai $_city - $_goal',
          style: const TextStyle(fontSize: 12, color: GymColors.muted),
        ),
        const SectionHeading(title: 'Goi y phu hop'),
        if (profiles.isEmpty)
          const GymCard(
            child: Text(
              'Chua co ho so phu hop voi bo loc nay.',
              style: TextStyle(fontSize: 13, color: GymColors.muted),
            ),
          )
        else
          for (final profile in profiles) ...[
            _profileCard(profile),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _composer() => GymCard(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundImage: AssetImage('assets/images/avatar.jpg'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            key: const Key('create-post'),
            onPressed: _openPostForm,
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: const Text('Chia se buoi tap cua ban...'),
          ),
        ),
      ],
    ),
  );

  Widget _feed() => AnimatedBuilder(
    animation: _postController,
    builder: (context, _) {
      if (_postController.loading && _postController.posts.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _composer(),
          const SizedBox(height: 12),
          if (_postController.loading) const LinearProgressIndicator(),
          if (_postController.error != null) ...[
            GymCard(
              child: Column(
                children: [
                  Text(_postController.error!, textAlign: TextAlign.center),
                  TextButton.icon(
                    key: const Key('feed-retry'),
                    onPressed:
                        _postController.loading || _postController.loadingMore
                        ? null
                        : _postController.posts.isEmpty
                        ? _postController.loadPosts
                        : _retryFeed,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_postController.posts.isEmpty && _postController.error == null)
            const GymCard(
              key: Key('feed-empty'),
              child: Text(
                'Chưa có bài viết. Hãy chia sẻ buổi tập đầu tiên của bạn!',
              ),
            ),
          for (var i = 0; i < _postController.posts.length; i++) ...[
            _postCard(_postController.posts[i], i == 0),
            const SizedBox(height: 12),
          ],
          if (_postController.loadingMore)
            const Center(child: CircularProgressIndicator())
          else if (_postController.hasMore && _postController.error == null)
            OutlinedButton(
              key: const Key('feed-load-more'),
              onPressed: _postController.loading
                  ? null
                  : _postController.loadMore,
              child: const Text('Tải thêm'),
            ),
        ],
      );
    },
  );

  Future<void> _retryFeed() => _postController.loadMoreFailed
      ? _postController.loadMore()
      : _postController.loadPosts();

  Future<void> _refreshFeed() => _postController.loadPosts();

  Widget _postCard(Post post, bool firstPost) {
    final commentCount = 23 + post.comments.length;
    return GymCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: AssetImage(post.avatarAsset),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Vua cap nhat',
                        style: TextStyle(fontSize: 10, color: GymColors.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF352042),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    post.tag,
                    style: const TextStyle(
                      fontSize: 10,
                      color: GymColors.purple,
                    ),
                  ),
                ),
                IconButton(
                  key: Key('post-menu-${post.id}'),
                  tooltip: 'Mo tuy chon bai dang',
                  onPressed: () => _openPostActions(post),
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),
          if (post.imageAsset != null) _postImage(post.imageAsset!),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 3),
            child: Text(
              post.content,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Row(
              children: [
                TextButton.icon(
                  key: firstPost
                      ? const Key('community-like')
                      : Key('like-${post.id}'),
                  onPressed:
                      _postController.isLiking(post.id) ||
                          _postController.loading ||
                          _postController.loadingMore
                      ? null
                      : () async {
                          final saved = await _postController.toggleLike(
                            post.id,
                          );
                          if (!mounted) return;
                          if (!saved) {
                            showMessage(
                              context,
                              'Không thể cập nhật lượt thích. Vui lòng thử lại.',
                            );
                          }
                        },
                  icon: Icon(
                    post.liked ? Icons.favorite : Icons.favorite_border,
                    size: 19,
                    semanticLabel: post.liked ? 'Bỏ thích' : 'Thích',
                  ),
                  label: Text(
                    '${post.likeCount}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: GymColors.purple,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  key: firstPost
                      ? const Key('community-comments')
                      : Key('comments-${post.id}'),
                  onPressed: () => _openComments(post),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(
                    '$commentCount',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(foregroundColor: GymColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _postImage(String source) {
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        const SizedBox(
          height: 204,
          width: double.infinity,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              semanticLabel: 'Không thể tải ảnh',
            ),
          ),
        );
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        source,
        width: double.infinity,
        height: 204,
        fit: BoxFit.cover,
        errorBuilder: fallback,
      );
    }
    return Image.asset(
      source,
      width: double.infinity,
      height: 204,
      fit: BoxFit.cover,
      errorBuilder: fallback,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 17, 20, 10),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Kham Pha',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('community-filter'),
              onPressed: _filters,
              icon: const Icon(Icons.tune, size: 14),
              label: Text(
                '$_city - $_goal',
                style: const TextStyle(fontSize: 10),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tab == i
                              ? GymColors.purple
                              : GymColors.border,
                          width: _tab == i ? 2 : 1,
                        ),
                      ),
                    ),
                    child: Text(
                      i == 0 ? 'Cong dong' : 'Tim PT / Ban tap',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _tab == i ? GymColors.purple : GymColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _tab == 0 ? _refreshFeed : () async {},
          notificationPredicate: (_) => _tab == 0,
          child: SingleChildScrollView(
            key: const Key('community-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [if (_tab == 0) _feed(), if (_tab == 1) _finder()],
            ),
          ),
        ),
      ),
    ],
  );
}
