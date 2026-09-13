import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/mindmap_node.dart';
import '../../widgets/mindmap_canvas.dart';
import '../main_screen.dart'; // for CreatePostPage, PostReplyPage (defined in main_screen.dart)
import '../notes_screen.dart';
import 'group_invite_page.dart';

/// 群組詳細頁（動態牆 + 成員）
class GroupDetailPage extends StatefulWidget {
  final Map<String, dynamic> group;
  final Map<String, dynamic> currentUser;
  final String? inviteType;
  final String? inviteRefId;

  const GroupDetailPage({
    super.key,
    required this.group,
    required this.currentUser,
    this.inviteType,
    this.inviteRefId,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _group;

  Map<String, dynamic>? _membership;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isJoining = false;
  bool _requiresApproval = false;
  Map<String, dynamic>? _replyingPost;

  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  bool _isSending = false;

  String get _currentUserId => widget.currentUser['id'].toString();
  bool get _isGuest => _currentUserId == 'u4';
  bool get _isPrivate => _group['type'] == 'private';
  bool get _isOwner =>
      _group['owner_id'].toString() == _currentUserId ||
      (_membership != null && _membership!['role'] == 'owner');
  bool get _isMember =>
      _isOwner || (_membership != null && _membership!['status'] == 'active');
  bool get _isPending =>
      !_isOwner && _membership != null && _membership!['status'] == 'pending';
  bool get _isOwnerOrAdmin =>
      _isOwner ||
      (_membership != null &&
          (_membership!['role'] == 'owner' || _membership!['role'] == 'admin'));

  @override
  void initState() {
    super.initState();
    _group = Map<String, dynamic>.from(widget.group);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final groupId = _group['id'] as int;
      var membership = await DatabaseHelper.instance
          .getGroupMembership(groupId, _currentUserId);
      final updatedGroup = await DatabaseHelper.instance.getGroupById(groupId);

      final isOwner = _group['owner_id'].toString() == _currentUserId ||
          (membership != null && membership['role'] == 'owner');

      if (isOwner && (membership == null || membership['status'] != 'active')) {
        await DatabaseHelper.instance
            .joinGroup(groupId, _currentUserId, isPending: false);
        final db = await DatabaseHelper.instance.database;
        await db.execute(
          "UPDATE group_members SET role = 'owner', status = 'active' WHERE group_id = ? AND user_id = ?",
          [groupId, _currentUserId],
        );
        membership = await DatabaseHelper.instance
            .getGroupMembership(groupId, _currentUserId);
      }

      List<Map<String, dynamic>> posts = [];
      List<Map<String, dynamic>> members = [];

      // 如果是成員（含創辦人）或公開群組，載入貼文
      final isMember =
          isOwner || (membership != null && membership['status'] == 'active');
      final isPublic = (updatedGroup?['type'] ?? 'public') == 'public';

      if (isMember) {
        await DatabaseHelper.instance.markGroupAsRead(groupId, _currentUserId);
      }

      if (isMember || isPublic) {
        final rawPosts = await DatabaseHelper.instance.getGroupPosts(groupId);
        final db = await DatabaseHelper.instance.database;
        for (var p in rawPosts) {
          final u = await db
              .query('users', where: 'id = ?', whereArgs: [p['user_id']]);
          final author = u.isNotEmpty
              ? u.first['display_name'] as String? ?? '未知用戶'
              : '未知用戶';
          final likes = await db.query('post_likes',
              where: 'post_id = ? AND user_id = ?',
              whereArgs: [p['id'], _currentUserId]);
          final replies = await db.rawQuery(
              'SELECT COUNT(*) as c FROM comments WHERE post_id = ?',
              [p['id']]);
          final attached = jsonDecode((p['attached_data'] as String?) ?? '{}');
          posts.add({
            'id': p['id'],
            'userId': p['user_id'],
            'author': author,
            'authorAvatarColor':
                u.isNotEmpty ? (u.first['avatar_color'] as int? ?? 0) : 0,
            'authorAvatarBlob':
                u.isNotEmpty ? u.first['avatar_blob'] as Uint8List? : null,
            'authorAvatarSelected':
                u.isNotEmpty ? (u.first['avatar_selected'] as int? ?? 0) : 0,
            'authorBio': u.isNotEmpty ? (u.first['bio'] as String? ?? '') : '',
            'time': formatRelativeTime(p['created_at']),
            'content': p['content'],
            'postType': p['type'] ?? 'text',
            'isEdited': (p['is_edited'] as int? ?? 0),
            'isLiked': likes.isNotEmpty,
            'likes': p['likes'] ?? 0,
            'replies': (replies.first['c'] as int?) ?? 0,
            'media': attached['media_url'],
            'media_blob': p['media_blob'] as Uint8List?,
            'file_blob': p['file_blob'] as Uint8List?,
            'fileName': attached['file_name'],
            'attached_data': attached,
            'replyTo': attached['reply_to'],
          });
        }
      }

      members = await DatabaseHelper.instance.getGroupMembers(groupId);

      bool requiresApproval =
          (updatedGroup?['join_requires_approval'] as int? ??
                      _group['join_requires_approval'] as int?) ==
                  1 ||
              (((updatedGroup?['join_requires_approval'] ??
                          _group['join_requires_approval']) ==
                      null) &&
                  _isPrivate);

      if (widget.inviteType != null && widget.inviteRefId != null) {
        final db = await DatabaseHelper.instance.database;
        final refUserMembership = await db.query('group_members',
            where: 'group_id = ? AND user_id = ?',
            whereArgs: [groupId, widget.inviteRefId]);

        bool refIsAdmin = false;
        if (refUserMembership.isNotEmpty) {
          final role = refUserMembership.first['role'] as String?;
          refIsAdmin = role == 'owner' || role == 'admin';
        }

        if (widget.inviteType == 'approval') {
          requiresApproval = true;
        } else if (widget.inviteType == 'auto') {
          if (refIsAdmin) {
            requiresApproval = false; // 管理員產生的 auto 連結可直接加入
          } else if (_isPrivate) {
            requiresApproval = true; // 私人群組中，一般成員產生的 auto 連結無效，強制審核
          } else {
            requiresApproval = false; // 公開群組一般成員的 auto 連結有效
          }
        }
      }

      if (mounted) {
        setState(() {
          _group = updatedGroup ?? _group;
          _membership = membership;
          _posts = posts;
          _members = members;
          _requiresApproval = requiresApproval;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('GroupDetailPage _loadData error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinOrApply() async {
    if (_isGuest) {
      _showGuestPrompt();
      return;
    }
    setState(() => _isJoining = true);
    try {
      final groupId = _group['id'] as int;

      await DatabaseHelper.instance.joinGroup(
        groupId,
        _currentUserId,
        isPending: _requiresApproval,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_requiresApproval ? '已送出申請，等待管理員審核' : '🎉 成功加入群組！'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失敗：$e')),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('離開群組？'),
        content: Text('確定要離開「${_group['name']}」嗎？之後可以再次申請加入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('離開'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance
        .leaveGroup(_group['id'] as int, _currentUserId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _kickMember(Map<String, dynamic> m) async {
    final name = m['display_name'] as String? ?? '此成員';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.person_remove_rounded, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('剔除成員', style: TextStyle(fontSize: 18)),
        ]),
        content: Text('確定要將「$name」移出群組嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('剔除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance
        .leaveGroup(_group['id'] as int, m['user_id'].toString());
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已將 $name 移出群組'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteGroup() async {
    final groupName = _group['name'] as String? ?? '群組';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('刪除群組', style: TextStyle(fontSize: 18)),
        ]),
        content: Text('⚠️ 確定要刪除群組「$groupName」嗎？\n此動作將會刪除所有群組貼文與成員紀錄，且無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance.deleteGroup(_group['id'] as int);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已刪除群組「$groupName」'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _toggleMute() async {
    final newMuted = await DatabaseHelper.instance
        .toggleGroupMute(_group['id'] as int, _currentUserId);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newMuted ? '🔕 已將群組設定為靜音' : '🔔 已開啟群組通知'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  Future<void> _markUnread() async {
    await DatabaseHelper.instance
        .markGroupAsUnread(_group['id'] as int, _currentUserId);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔴 已標示為未讀'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  Future<void> _approveRequest(
      Map<String, dynamic> member, bool approved) async {
    await DatabaseHelper.instance.approveGroupRequest(
        _group['id'] as int, member['user_id'].toString(), approved);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(approved ? '✅ 已同意 ${member['display_name']} 加入' : '已拒絕申請'),
          backgroundColor:
              approved ? Theme.of(context).primaryColor : Colors.grey,
        ),
      );
    }
  }

  void _showGuestPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('請先登入才能加入群組')),
    );
  }

  // ── 發文按鈕（成員才可見）──
  void _openCreatePost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostPage(
          currentUser: widget.currentUser,
          onPosted: _loadData,
          groupId: _group['id'] as int,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupName = _group['name'] as String? ?? '群組';
    final iconEmoji = _group['icon_emoji'] as String? ?? '📚';
    final desc = _group['description'] as String? ?? '';
    final memberCount = _group['member_count'] as int? ?? 0;
    final tags = jsonDecode((_group['tags'] as String?) ?? '[]') as List;

    final int pendingCount =
        _members.where((m) => m['status'] == 'pending').length;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F0EE),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            elevation: 0,
            pinned: true,
            expandedHeight: 200,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_isMember)
                IconButton(
                  icon: const Icon(Icons.link_rounded),
                  tooltip: '邀請連結管理',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupInvitePage(
                          group: _group,
                          currentUserId: _currentUserId,
                          isOwnerOrAdmin: _isOwnerOrAdmin,
                        ),
                      ),
                    );
                  },
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (val) {
                  if (val == 'leave') {
                    _leaveGroup();
                  } else if (val == 'delete') {
                    _deleteGroup();
                  } else if (val == 'mute') {
                    _toggleMute();
                  } else if (val == 'unread') {
                    _markUnread();
                  }
                },
                itemBuilder: (ctx) {
                  final bool isMuted = (_membership != null &&
                      (_membership!['is_muted'] as int? ?? 0) == 1);
                  return [
                    if (_isMember) ...[
                      PopupMenuItem(
                        value: 'mute',
                        child: Row(
                          children: [
                            Icon(
                                isMuted
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_off_rounded,
                                color: Theme.of(context).primaryColor,
                                size: 18),
                            const SizedBox(width: 8),
                            Text(isMuted ? '開啟群組通知 🔔' : '關閉群組通知 (靜音) 🔕'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'unread',
                        child: Row(
                          children: [
                            Icon(Icons.mark_chat_unread_rounded,
                                color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Text('標示為未讀'),
                          ],
                        ),
                      ),
                    ],
                    if (_isMember && !_isOwner)
                      const PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app_rounded,
                                color: Colors.redAccent, size: 18),
                            SizedBox(width: 8),
                            Text('離開群組',
                                style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    if (_isOwner)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever_rounded,
                                color: Colors.redAccent, size: 18),
                            SizedBox(width: 8),
                            Text('刪除群組',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ];
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF2C1F1A),
                            const Color(0xFF1A1A1A),
                          ]
                        : [
                            const Color(0xFFFDF0E8),
                            const Color(0xFFF5E8DF),
                          ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(iconEmoji,
                                    style: const TextStyle(fontSize: 32)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          groupName,
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF3E2723),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _isPrivate
                                              ? Colors.orange
                                                  .withValues(alpha: 0.15)
                                              : Colors.blue
                                                  .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _isPrivate ? '🔒 私人' : '🌐 公開',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _isPrivate
                                                  ? Colors.orange.shade700
                                                  : Colors.blue.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$memberCount 位成員',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark
                                            ? Colors.white60
                                            : Theme.of(context).primaryColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            desc,
                            style: TextStyle(
                                fontSize: 13,
                                color:
                                    isDark ? Colors.white60 : Colors.black54),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: tags
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(t.toString(),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .primaryColor)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Theme.of(context).primaryColor,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor:
                      isDark ? Colors.white54 : Colors.black54,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13.5),
                  tabs: [
                    const Tab(text: '動態'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('成員'),
                          if (_isOwnerOrAdmin && pendingCount > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('$pendingCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFeedTab(isDark, pendingCount),
            _buildMembersTab(isDark),
          ],
        ),
      ),
      // ── 加入 / 申請 按鈕（非成員顯示）──
      floatingActionButton: _isLoading
          ? null
          : _isMember
              ? null
              : (_isPrivate && _tabController.index == 0)
                  ? null // 私人群組在「動態」Tab 中已有中央解鎖 Overlay 按鈕，不重複顯示 FAB
                  : _isPending
                      ? null
                      : _buildJoinButton(),
      bottomNavigationBar: (_isMember && _tabController.index == 0)
          ? _buildChatInputBar(isDark)
          : null,
    );
  }

  // ── 動態 Tab ────────────────────────────────────────────────────
  Widget _buildFeedTab(bool isDark, int pendingCount) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 私人群組：非成員看到模糊效果
    if (_isPrivate && !_isMember) {
      return _buildPrivateOverlay(isDark);
    }

    final bool showPendingBanner = _isOwnerOrAdmin && pendingCount > 0;

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showPendingBanner)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildPendingNotificationBanner(pendingCount, isDark),
              ),
            Text((_group['icon_emoji'] as String? ?? '📚'),
                style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              '還沒有任何貼文',
              style: TextStyle(
                  fontSize: 15, color: isDark ? Colors.white54 : Colors.grey),
            ),
            if (_isMember) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _openCreatePost,
                child: Text('發表第一篇貼文',
                    style: TextStyle(color: Theme.of(context).primaryColor)),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Theme.of(context).primaryColor,
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: _posts.length + (showPendingBanner ? 1 : 0),
        itemBuilder: (context, idx) {
          if (showPendingBanner && idx == _posts.length) {
            return _buildPendingNotificationBanner(pendingCount, isDark);
          }
          final p = _posts[idx];
          return _buildChatBubble(p, isDark);
        },
      ),
    );
  }

  Widget _buildPendingNotificationBanner(int pendingCount, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2216) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFF9800),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔔 有 $pendingCount 位成員申請加入群組！',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFFFCC80)
                          : const Color(0xFF8D4200)),
                ),
                Text(
                  '點擊「立即審核」移至成員頁面處理',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : const Color(0xFFA0522D)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _tabController.animateTo(1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('立即審核',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateOverlay(bool isDark) {
    return Stack(
      children: [
        // 模糊假貼文
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: 4,
          itemBuilder: (context, idx) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        // 鎖定浮層
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  (isDark ? Colors.black : Colors.white)
                      .withValues(alpha: 0.85),
                  (isDark ? Colors.black : Colors.white),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Color(0xFFFF9800), size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  '私人群組',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  _requiresApproval ? '申請加入經管理員審核後，即可查看群組動態' : '加入群組後，即可查看群組動態',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                if (_isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.orange, strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('申請審核中...',
                            style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isJoining ? null : _joinOrApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _requiresApproval
                          ? const Color(0xFFFF9800)
                          : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                      elevation: 3,
                    ),
                    icon: _isJoining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(
                            _requiresApproval
                                ? Icons.lock_open_rounded
                                : Icons.group_add_rounded,
                            size: 18),
                    label: Text(_requiresApproval ? '申請加入' : '加入群組',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final attachedData = <String, dynamic>{};
      if (_replyingPost != null) {
        attachedData['reply_to'] = {
          'id': _replyingPost!['id'],
          'author': _replyingPost!['author'],
          'content': _replyingPost!['content'],
        };
      }
      await db.insert('posts', <String, Object?>{
        'group_id': _group['id'],
        'user_id': _currentUserId,
        'content': text,
        'type': 'text',
        'is_edited': 0,
        'attached_data': jsonEncode(attachedData),
        'created_at': DateTime.now().toIso8601String(),
      });
      _chatController.clear();
      _replyingPost = null;
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發送失敗：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Widget _buildChatInputBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top:
              BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingPost != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.orange.withValues(alpha: 0.12)
                    : const Color(0xFFFFF8F0),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply_rounded,
                      size: 16, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '正在回覆 ${_replyingPost!['author']}：${_replyingPost!['content']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingPost = null),
                    child: Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: 8 +
                  MediaQuery.of(context).viewInsets.bottom +
                  (MediaQuery.of(context).viewInsets.bottom > 0
                      ? 4
                      : MediaQuery.of(context).padding.bottom),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  color: Colors.grey,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('傳送圖片功能開發中')),
                    );
                  },
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _chatController,
                      focusNode: _chatFocusNode,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      decoration: const InputDecoration(
                        hintText: '輸入訊息...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: Theme.of(context).primaryColor,
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(Map<String, dynamic> p) async {
    final postId = p['id'] as int;
    final isLiked = p['isLiked'] == true;
    final currentLikes = p['likes'] as int? ?? 0;

    // Optimistic UI update
    setState(() {
      p['isLiked'] = !isLiked;
      p['likes'] = isLiked
          ? (currentLikes > 0 ? currentLikes - 1 : 0)
          : (currentLikes + 1);
    });

    final db = await DatabaseHelper.instance.database;
    if (isLiked) {
      await db.delete('post_likes',
          where: 'post_id = ? AND user_id = ?',
          whereArgs: [postId, _currentUserId]);
      await db.execute(
          'UPDATE posts SET likes = MAX(0, likes - 1) WHERE id = ?', [postId]);
    } else {
      await db.insert('post_likes',
          <String, Object?>{'post_id': postId, 'user_id': _currentUserId});
      await db
          .execute('UPDATE posts SET likes = likes + 1 WHERE id = ?', [postId]);
    }
  }

  void _replyToPost(Map<String, dynamic> post) {
    final authorName = post['author'] ?? '未知';
    setState(() {
      _replyingPost = post;
      _chatController.text = '@$authorName ';
      _chatController.selection = TextSelection.fromPosition(
        TextPosition(offset: _chatController.text.length),
      );
    });
    _chatFocusNode.requestFocus();
  }

  Widget _buildChatBubble(Map<String, dynamic> p, bool isDark) {
    final bool isMe = p['userId'] == _currentUserId;
    final Color bubbleColor = isMe
        ? Theme.of(context).primaryColor
        : (isDark ? const Color(0xFF2C2C2C) : Colors.white);
    final Color textColor =
        isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final replyTo = p['replyTo'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => _showMemberProfileDialog(
                name: p['author'] ?? '未知',
                avatarBlob: p['authorAvatarBlob'] as Uint8List?,
                avatarColor: (p['authorAvatarColor'] as int?) ??
                    getAvatarColorIdx(p['author'] ?? ''),
                usePreset: (p['authorAvatarSelected'] as int? ?? 0) == 1 &&
                    p['authorAvatarBlob'] == null,
                userId: p['userId']?.toString(),
              ),
              child: buildAvatar(
                blob: p['authorAvatarBlob'] as Uint8List?,
                colorIdx: (p['authorAvatarColor'] as int?) ??
                    getAvatarColorIdx(p['author'] ?? ''),
                initial: (p['author'] ?? '?').substring(0, 1),
                radius: 16,
                usePreset: (p['authorAvatarSelected'] as int? ?? 0) == 1 &&
                    p['authorAvatarBlob'] == null,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      p['author'] ?? '未知',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (replyTo != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              color: isMe
                                  ? Colors.black.withValues(alpha: 0.15)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.04)),
                              child: IntrinsicHeight(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 3,
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.6)
                                          : Theme.of(context)
                                              .primaryColor
                                              .withValues(alpha: 0.7),
                                    ),
                                    Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              replyTo['author'] ?? '未知',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isMe
                                                    ? Colors.white
                                                        .withValues(alpha: 0.95)
                                                    : Theme.of(context)
                                                        .primaryColor,
                                              ),
                                            ),
                                            Text(
                                              replyTo['content'] ?? '',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isMe
                                                    ? Colors.white
                                                        .withValues(alpha: 0.85)
                                                    : (isDark
                                                        ? Colors.white70
                                                        : Colors.black87),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      Builder(
                        builder: (context) {
                          Map<String, dynamic> attachedData = {};
                          try {
                            if (p['attached_data'] != null) {
                              if (p['attached_data'] is Map) {
                                attachedData = Map<String, dynamic>.from(
                                    p['attached_data'] as Map);
                              } else if (p['attached_data'] is String &&
                                  (p['attached_data'] as String).isNotEmpty) {
                                attachedData =
                                    jsonDecode(p['attached_data'] as String)
                                        as Map<String, dynamic>;
                              }
                            }
                          } catch (_) {}

                          final bool isNotePost = p['postType'] == 'note' ||
                              attachedData['shared_type'] == 'note';

                          if (isNotePost) {
                            return _buildSharedNoteCardInChat(
                                attachedData, isMe, isDark, p);
                          }

                          return Text(
                            p['content'] ?? '',
                            style: TextStyle(
                                fontSize: 15, color: textColor, height: 1.3),
                          );
                        },
                      ),
                      if (p['media_blob'] != null ||
                          (p['media'] != null &&
                              p['media'].toString().isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            Map<String, dynamic> attachedData = {};
                            try {
                              if (p['attached_data'] != null) {
                                if (p['attached_data'] is Map) {
                                  attachedData = Map<String, dynamic>.from(
                                      p['attached_data'] as Map);
                                } else if (p['attached_data'] is String &&
                                    (p['attached_data'] as String).isNotEmpty) {
                                  attachedData =
                                      jsonDecode(p['attached_data'] as String)
                                          as Map<String, dynamic>;
                                }
                              }
                            } catch (_) {}
                            final double alignX =
                                (attachedData['img_align_x'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                            final double alignY =
                                (attachedData['img_align_y'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                            final Alignment imgAlignment =
                                Alignment(alignX, alignY);

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (p['media_blob'] != null)
                                  ? Image.memory(p['media_blob'] as Uint8List,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 160,
                                      alignment: imgAlignment)
                                  : _buildNetworkOrFile(
                                      p['media'].toString(), imgAlignment),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p['time'] ?? '',
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade500),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _toggleLike(p),
                        child: Row(
                          children: [
                            Icon(
                              p['isLiked'] == true
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: p['isLiked'] == true
                                  ? Colors.redAccent
                                  : (isDark
                                      ? Colors.white38
                                      : Colors.grey.shade400),
                            ),
                            const SizedBox(width: 4),
                            Text('${p['likes'] ?? 0}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _replyToPost(p),
                        child: Row(
                          children: [
                            Icon(Icons.mode_comment_outlined,
                                size: 14,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text('回覆',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkOrFile(String src, Alignment alignment) {
    if (src.startsWith('data:image')) {
      return Image.memory(base64Decode(src.split(',').last),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 160,
          alignment: alignment);
    } else if (src.startsWith('http') || kIsWeb) {
      return Image.network(src,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 160,
          alignment: alignment);
    } else {
      return Image.file(File(src),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 160,
          alignment: alignment);
    }
  }

  // ── 群組內學習筆記卡片預覽與一鍵匯入 ──────────────────────────
  Widget _buildSharedNoteCardInChat(Map<String, dynamic> attached, bool isMe,
      bool isDark, Map<String, dynamic> post) {
    final String title = attached['title'] ?? '無標題筆記';
    final String content = attached['content'] ?? '';
    final String category = attached['category'] ?? '學習';
    final bool hasStrokes = attached['strokes'] != null &&
        attached['strokes'].toString().isNotEmpty &&
        attached['strokes'].toString() != '[]';

    final Color cardBg = isMe
        ? Colors.black.withValues(alpha: 0.15)
        : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFBF8F5));
    final Color borderColor = isMe
        ? Colors.white.withValues(alpha: 0.3)
        : (isDark ? Colors.white12 : const Color(0xFFE2D6CA));
    final Color titleColor =
        isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF3E2723));
    final Color subtitleColor = isMe
        ? Colors.white.withValues(alpha: 0.85)
        : (isDark ? Colors.white70 : Colors.black87);

    final bool hasMindmap = attached['mindmap_json'] != null;

    return InkWell(
      onTap: () => _showNotePreviewDialog(post, attached),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 275,
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頂部標籤列
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 16,
                    color: isMe ? Colors.white : Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '學習筆記分享',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.25)
                        : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color:
                          isMe ? Colors.white : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 筆記標題
            Text(
              '《$title》',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: titleColor,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),

            // 內容摘要
            Text(
              content.isEmpty
                  ? '（空白筆記內容）'
                  : content.replaceAll('#', '').replaceAll('**', '').trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: subtitleColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),

            // 塗鴉/心智圖標記 + 預覽與匯入按鈕
            Row(
              children: [
                if (hasMindmap)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.25)
                            : const Color(0xFF4A148C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hub_outlined,
                              size: 10,
                              color: isMe
                                  ? Colors.white
                                  : const Color(0xFF4A148C)),
                          const SizedBox(width: 2),
                          Text('心智圖',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF4A148C))),
                        ],
                      ),
                    ),
                  ),
                if (hasStrokes)
                  Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 13,
                        color: isMe
                            ? Colors.white70
                            : (isDark ? Colors.white60 : Colors.blueGrey),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '手繪',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isMe
                              ? Colors.white70
                              : (isDark ? Colors.white60 : Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _showNotePreviewDialog(post, attached),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isMe ? Colors.white : Theme.of(context).primaryColor,
                    side: BorderSide(
                        color: isMe
                            ? Colors.white70
                            : Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.5)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded, size: 13),
                      SizedBox(width: 3),
                      Text('預覽',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                ElevatedButton.icon(
                  onPressed: () => _importSharedNote(post),
                  icon: const Icon(Icons.download_rounded, size: 13),
                  label: const Text('匯入',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isMe ? Colors.white : Theme.of(context).primaryColor,
                    foregroundColor:
                        isMe ? Theme.of(context).primaryColor : Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotePreviewDialog(
      Map<String, dynamic> p, Map<String, dynamic> attached) {
    final String rawTitle = attached['title'] as String? ?? '';
    final String rawContent = attached['content'] as String? ?? '';
    final String pContent = p['content'] as String? ?? '';
    final String title = rawTitle.isNotEmpty ? rawTitle : '無標題筆記';
    final String content = rawContent.isNotEmpty ? rawContent : pContent;
    final String category = (attached['category'] as String? ?? '').isNotEmpty
        ? (attached['category'] as String)
        : '學習';
    final String authorName = p['author'] as String? ?? '未知用戶';
    final String timeStr = p['time'] as String? ??
        (p['created_at']?.toString().split('T').first ?? '');

    // 解析 strokes
    final List<Stroke> strokes = [];
    final String? strokesJson = attached['strokes'];
    if (strokesJson != null && strokesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(strokesJson) as List;
        for (var s in decoded) {
          strokes.add(Stroke.fromJson(s as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('解析筆記繪圖失敗: $e');
      }
    }

    // 解析 mindmap
    MindMapNode? mindmapNode;
    if (attached['mindmap_json'] != null) {
      try {
        final mindmapMap = attached['mindmap_json'] is Map
            ? Map<String, dynamic>.from(attached['mindmap_json'] as Map)
            : jsonDecode(attached['mindmap_json'].toString())
                as Map<String, dynamic>;
        mindmapNode = MindMapNode.fromJson(mindmapMap);
      } catch (e) {
        debugPrint('解析心智圖失敗: $e');
      }
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderCol =
        isDark ? Colors.white12 : primaryColor.withValues(alpha: 0.18);

    showDialog(
      context: context,
      builder: (ctx) {
        int selectedTab = 0; // 0: 文字, 1: 塗鴉, 2: 心智圖

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final hasStrokes = strokes.isNotEmpty;
            final hasMindmap = mindmapNode != null;

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                  maxWidth: 600,
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 頂部標題與關閉按鈕
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.sticky_note_2_rounded,
                              color: primaryColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF3E2723),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 作者資訊與分類標籤
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '•  由 $authorName 分享${timeStr.isNotEmpty ? ' 於 $timeStr' : ''}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 頁籤切換器 (若包含多種媒體類型)
                    if (hasStrokes || hasMindmap) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () =>
                                    setStateDialog(() => selectedTab = 0),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    color: selectedTab == 0
                                        ? (isDark
                                            ? const Color(0xFF2C2C2C)
                                            : Colors.white)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: selectedTab == 0
                                        ? [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.06),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    '📝 文字紀錄',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: selectedTab == 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: selectedTab == 0
                                          ? primaryColor
                                          : (isDark
                                              ? Colors.white60
                                              : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (hasStrokes)
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      setStateDialog(() => selectedTab = 1),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                      color: selectedTab == 1
                                          ? (isDark
                                              ? const Color(0xFF2C2C2C)
                                              : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: selectedTab == 1
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.06),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      '🎨 手寫塗鴉',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: selectedTab == 1
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: selectedTab == 1
                                            ? primaryColor
                                            : (isDark
                                                ? Colors.white60
                                                : Colors.black54),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (hasMindmap)
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      setStateDialog(() => selectedTab = 2),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                      color: selectedTab == 2
                                          ? (isDark
                                              ? const Color(0xFF2C2C2C)
                                              : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: selectedTab == 2
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.06),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      '🧠 心智圖',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: selectedTab == 2
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: selectedTab == 2
                                            ? const Color(0xFF4A148C)
                                            : (isDark
                                                ? Colors.white60
                                                : Colors.black54),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 筆記內容主要呈現區
                    Flexible(
                      child: Container(
                        height: 380,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF25252A)
                              : const Color(0xFFFDFCFA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderCol, width: 1.2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: selectedTab == 1 && hasStrokes
                              ? CustomPaint(
                                  painter: StrokePainter(strokes: strokes),
                                )
                              : selectedTab == 2 && hasMindmap
                                  ? Stack(
                                      children: [
                                        InteractiveMindMapView(
                                            root: mindmapNode),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: TextButton.icon(
                                            onPressed: () {
                                              FullscreenMindMapView.open(
                                                context,
                                                root: mindmapNode!,
                                                title: title,
                                              );
                                            },
                                            icon: const Icon(
                                                Icons.fullscreen_rounded,
                                                size: 16),
                                            label: const Text('全螢幕',
                                                style: TextStyle(fontSize: 11)),
                                            style: TextButton.styleFrom(
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.9),
                                              foregroundColor:
                                                  const Color(0xFF4A148C),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              elevation: 1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Stack(
                                      children: [
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: PaperBackgroundPainter(),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: SingleChildScrollView(
                                            padding: const EdgeInsets.fromLTRB(
                                                48, 16, 20, 16),
                                            child: RichNoteContentView(
                                              content: content,
                                              isDark: isDark,
                                              selectable: true,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 底部操作列
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('關閉',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 17),
                          label: const Text('匯入至我的筆記本',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _importSharedNote(p);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _importSharedNote(Map<String, dynamic> p) {
    final attached = p['attached_data'];
    if (attached == null) return;
    try {
      final Map<String, dynamic> attachedData = (attached is Map)
          ? Map<String, dynamic>.from(attached)
          : (attached is String && attached.isNotEmpty
              ? jsonDecode(attached) as Map<String, dynamic>
              : {});

      final String title = attachedData['title'] ?? '無標題筆記';
      final String content = attachedData['content'] ?? '';
      final String category = attachedData['category'] ?? '學習';
      final String authorName = p['author'] ?? '未知用戶';
      final String authorUserId = p['userId']?.toString() ?? '';
      final int authorAvatarColor = (p['authorAvatarColor'] as int?) ?? 0;

      final List<Stroke> strokes = [];
      final String? strokesJson = attachedData['strokes'];
      if (strokesJson != null && strokesJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(strokesJson) as List;
          for (var s in decoded) {
            strokes.add(Stroke.fromJson(s as Map<String, dynamic>));
          }
        } catch (e) {
          debugPrint('解析筆記繪圖失敗: $e');
        }
      }

      final Map<String, dynamic>? mindmapJson = attachedData['mindmap_json'] !=
              null
          ? (attachedData['mindmap_json'] is Map
              ? Map<String, dynamic>.from(attachedData['mindmap_json'] as Map)
              : (attachedData['mindmap_json'] is String &&
                      (attachedData['mindmap_json'] as String).isNotEmpty
                  ? jsonDecode(attachedData['mindmap_json'] as String)
                      as Map<String, dynamic>
                  : null))
          : null;

      final newNote = Note(
        id: 'note_${DateTime.now().millisecondsSinceEpoch}',
        userId: widget.currentUser['id'],
        title: '$title (群組匯入)',
        content: content,
        category:
            NotesDatabase.categories.contains(category) ? category : '未分類',
        strokes: strokes,
        updatedAt: DateTime.now(),
        authorName: authorName,
        authorUserId: authorUserId,
        authorAvatarColor: authorAvatarColor,
        mindmapJson: mindmapJson,
      );

      // 匯入至 NotesDatabase 運行時列表中
      NotesDatabase.notes.insert(0, newNote);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('🎉 筆記已成功匯入至您的筆記本！')),
            ],
          ),
          backgroundColor: Theme.of(context).primaryColor,
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('匯入失敗: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ── 成員 Tab ────────────────────────────────────────────────────
  Widget _buildMembersTab(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final active = _members.where((m) => m['status'] == 'active').toList();
    final pending = _members.where((m) => m['status'] == 'pending').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        if (pending.isNotEmpty && _isOwnerOrAdmin) ...[
          _sectionHeader('待審核申請', pending.length, isDark),
          const SizedBox(height: 8),
          ...pending.map((m) => _buildPendingCard(m, isDark)),
          const SizedBox(height: 16),
        ],
        _sectionHeader('成員', active.length, isDark),
        const SizedBox(height: 8),
        ...active.map((m) => _buildMemberCard(m, isDark)),
      ],
    );
  }

  Widget _sectionHeader(String title, int count, bool isDark) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : Colors.black45,
              letterSpacing: 0.5),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> m, bool isDark) {
    final name = m['display_name'] as String? ?? '未知用戶';
    final role = m['role'] as String? ?? 'member';
    final targetUserId = m['user_id'].toString();
    final bool canKick =
        _isOwnerOrAdmin && role != 'owner' && targetUserId != _currentUserId;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderCol = isDark ? Colors.white10 : Colors.grey.shade100;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showMemberProfileDialog(
              name: name,
              avatarBlob: m['avatar_blob'] as Uint8List?,
              avatarColor: m['avatar_color'] as int? ?? 0,
              usePreset: (m['avatar_selected'] as int? ?? 0) == 1 &&
                  m['avatar_blob'] == null,
              role: role,
              userId: m['user_id']?.toString(),
            ),
            child: buildAvatar(
              blob: m['avatar_blob'] as Uint8List?,
              colorIdx: m['avatar_color'] as int? ?? 0,
              initial: name.isNotEmpty ? name.substring(0, 1) : '?',
              radius: 18,
              usePreset: (m['avatar_selected'] as int? ?? 0) == 1 &&
                  m['avatar_blob'] == null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87)),
          ),
          _buildRoleBadge(role),
          if (canKick) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.person_remove_outlined,
                  color: Colors.redAccent, size: 20),
              tooltip: '剔除成員',
              onPressed: () => _kickMember(m),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> m, bool isDark) {
    final name = m['display_name'] as String? ?? '未知用戶';
    final cardBg =
        isDark ? Colors.orange.withValues(alpha: 0.08) : Colors.orange.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          buildAvatar(
            blob: m['avatar_blob'] as Uint8List?,
            colorIdx: m['avatar_color'] as int? ?? 0,
            initial: name.substring(0, 1),
            radius: 18,
            usePreset: (m['avatar_selected'] as int? ?? 0) == 1 &&
                m['avatar_blob'] == null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87)),
                const Text('⏳ 申請中',
                    style: TextStyle(fontSize: 11, color: Colors.orange)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle,
                    color: Color(0xFF4CAF50), size: 26),
                tooltip: '同意',
                onPressed: () => _approveRequest(m, true),
              ),
              IconButton(
                icon:
                    const Icon(Icons.cancel, color: Colors.redAccent, size: 26),
                tooltip: '拒絕',
                onPressed: () => _approveRequest(m, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    if (role == 'owner') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFCC80).withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('👑 創建者',
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFFB8860B),
                fontWeight: FontWeight.bold)),
      );
    } else if (role == 'admin') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('⚙️ 管理員',
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildJoinButton() {
    return FloatingActionButton.extended(
      heroTag: 'group_join_fab',
      onPressed: _isJoining ? null : _joinOrApply,
      backgroundColor: _requiresApproval
          ? const Color(0xFFFF9800)
          : Theme.of(context).primaryColor,
      icon: _isJoining
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : Icon(
              _requiresApproval
                  ? Icons.lock_open_rounded
                  : Icons.group_add_rounded,
              color: Colors.white),
      label: Text(
        _requiresApproval ? '申請加入' : '加入群組',
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  // ── 查看群組成員名片與簡介 ──
  Future<void> _showMemberProfileDialog({
    required String name,
    Uint8List? avatarBlob,
    int avatarColor = 0,
    bool usePreset = false,
    String? bio,
    String? role,
    String? userId,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final bool isMe =
        userId != null && userId == widget.currentUser['id'].toString();

    String effectiveBio = (bio ?? '').trim();
    if (userId != null && effectiveBio.isEmpty) {
      try {
        final db = await DatabaseHelper.instance.database;
        final rows =
            await db.query('users', where: 'id = ?', whereArgs: [userId]);
        if (rows.isNotEmpty) {
          effectiveBio = (rows.first['bio'] as String? ?? '').trim();
        }
      } catch (_) {}
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 頂部橫幅
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 90,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 16,
                          top: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.group_rounded,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  isMe ? '我的群組身分' : '群組成員名片',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: -35,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isDark ? const Color(0xFF1E1E22) : Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.4 : 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: buildAvatar(
                        blob: avatarBlob,
                        colorIdx: avatarColor,
                        initial: name.isNotEmpty ? name.substring(0, 1) : '?',
                        radius: 35,
                        usePreset: usePreset,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 42),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (role != null) ...[
                      _buildRoleBadge(role),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF26262B)
                            : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.format_quote_rounded,
                                  size: 15, color: primary),
                              const SizedBox(width: 6),
                              Text(
                                '個人簡介',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            effectiveBio.isNotEmpty
                                ? effectiveBio
                                : '這位成員很專注，尚未填寫個人簡介 🌱',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              fontStyle: effectiveBio.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: effectiveBio.isNotEmpty
                                  ? (isDark ? Colors.white70 : Colors.black87)
                                  : (isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark ? Colors.white60 : Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('關閉',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
