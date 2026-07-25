import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/common_widgets.dart';
import '../main_screen.dart'; // for CreatePostPage, PostReplyPage (defined in main_screen.dart)
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
      final updatedGroup =
          await DatabaseHelper.instance.getGroupById(groupId);

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
      final isMember = isOwner ||
          (membership != null && membership['status'] == 'active');
      final isPublic = (updatedGroup?['type'] ?? 'public') == 'public';

      if (isMember) {
        await DatabaseHelper.instance
            .markGroupAsRead(groupId, _currentUserId);
      }

      if (isMember || isPublic) {
        final rawPosts = await DatabaseHelper.instance
            .getGroupPosts(groupId);
        final db = await DatabaseHelper.instance.database;
        for (var p in rawPosts) {
          final u = await db.query('users',
              where: 'id = ?', whereArgs: [p['user_id']]);
          final author = u.isNotEmpty
              ? u.first['display_name'] as String? ?? '未知用戶'
              : '未知用戶';
          final likes = await db.query('post_likes',
              where: 'post_id = ? AND user_id = ?',
              whereArgs: [p['id'], _currentUserId]);
          final replies = await db.rawQuery(
              'SELECT COUNT(*) as c FROM comments WHERE post_id = ?',
              [p['id']]);
          final attached =
              jsonDecode((p['attached_data'] as String?) ?? '{}');
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
            'authorBio':
                u.isNotEmpty ? (u.first['bio'] as String? ?? '') : '',
            'time': formatRelativeTime(p['created_at']),
            'content': p['content'],
            'postType': p['type'] ?? 'text',
            'isEdited': (p['is_edited'] as int? ?? 0),
            'isLiked': likes.isNotEmpty,
            'likes': p['likes'] ?? 0,
            'replies': (replies.first['c'] as int?) ?? 0,
            'media': attached['media_url'],
            'media_blob': p['media_blob'] as Uint8List?,
            'attached_data': attached,
          });
        }
      }

      members = await DatabaseHelper.instance.getGroupMembers(groupId);

      bool requiresApproval = (updatedGroup?['join_requires_approval'] as int? ?? _group['join_requires_approval'] as int?) == 1 ||
          (((updatedGroup?['join_requires_approval'] ?? _group['join_requires_approval']) == null) && _isPrivate);

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
            backgroundColor: const Color(0xFF8D6E63),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('離開群組？'),
        content: Text(
            '確定要離開「${_group['name']}」嗎？之後可以再次申請加入。'),
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
    await DatabaseHelper.instance.leaveGroup(
        _group['id'] as int, _currentUserId);
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
    await DatabaseHelper.instance.leaveGroup(
        _group['id'] as int, m['user_id'].toString());
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
          backgroundColor: const Color(0xFF8D6E63),
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
        const SnackBar(
          content: Text('🔴 已標示為未讀'),
          backgroundColor: Color(0xFF8D6E63),
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
          content: Text(approved
              ? '✅ 已同意 ${member['display_name']} 加入'
              : '已拒絕申請'),
          backgroundColor:
              approved ? const Color(0xFF8D6E63) : Colors.grey,
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
            backgroundColor:
                isDark ? const Color(0xFF1A1A1A) : Colors.white,
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
                                color: const Color(0xFF8D6E63),
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
                                color: const Color(0xFF8D6E63)
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
                                              ? Colors.orange.withValues(alpha: 0.15)
                                              : Colors.blue.withValues(alpha: 0.12),
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
                                            : const Color(0xFF8D6E63)),
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
                                color: isDark
                                    ? Colors.white60
                                    : Colors.black54),
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
                                        color: const Color(0xFF8D6E63)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(t.toString(),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF8D6E63))),
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
                  indicatorColor: const Color(0xFF8D6E63),
                  labelColor: const Color(0xFF8D6E63),
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
                  fontSize: 15,
                  color: isDark ? Colors.white54 : Colors.grey),
            ),
            if (_isMember) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _openCreatePost,
                child: const Text('發表第一篇貼文',
                    style: TextStyle(color: Color(0xFF8D6E63))),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF8D6E63),
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
                      color: isDark ? const Color(0xFFFFCC80) : const Color(0xFF8D4200)),
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
                  (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
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
                      backgroundColor: _requiresApproval ? const Color(0xFFFF9800) : const Color(0xFF8D6E63),
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
                        : Icon(_requiresApproval ? Icons.lock_open_rounded : Icons.group_add_rounded, size: 18),
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
      await db.insert('posts', {
        'group_id': _group['id'],
        'user_id': _currentUserId,
        'content': text,
        'type': 'text',
        'is_edited': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      _chatController.clear();
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
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
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
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                maxLines: null,
                keyboardType: TextInputType.multiline,
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
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded),
                  color: const Color(0xFF8D6E63),
                  onPressed: _sendMessage,
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
      p['likes'] = isLiked ? (currentLikes > 0 ? currentLikes - 1 : 0) : (currentLikes + 1);
    });

    final db = await DatabaseHelper.instance.database;
    if (isLiked) {
      await db.delete('post_likes',
          where: 'post_id = ? AND user_id = ?',
          whereArgs: [postId, _currentUserId]);
      await db.execute('UPDATE posts SET likes = MAX(0, likes - 1) WHERE id = ?', [postId]);
    } else {
      await db.insert('post_likes', {'post_id': postId, 'user_id': _currentUserId});
      await db.execute('UPDATE posts SET likes = likes + 1 WHERE id = ?', [postId]);
    }
  }

  void _replyToPost(Map<String, dynamic> post) {
    final authorName = post['author'] ?? '未知';
    setState(() {
      _chatController.text = '@$authorName ';
    });
    _chatFocusNode.requestFocus();
  }

  Widget _buildChatBubble(Map<String, dynamic> p, bool isDark) {
    final bool isMe = p['userId'] == _currentUserId;
    final Color bubbleColor = isMe
        ? const Color(0xFF8D6E63)
        : (isDark ? const Color(0xFF2C2C2C) : Colors.white);
    final Color textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            buildAvatar(
              blob: p['authorAvatarBlob'] as Uint8List?,
              colorIdx: (p['authorAvatarColor'] as int?) ?? getAvatarColorIdx(p['author'] ?? ''),
              initial: (p['author'] ?? '?').substring(0, 1),
              radius: 16,
              usePreset: (p['authorAvatarSelected'] as int? ?? 0) == 1 && p['authorAvatarBlob'] == null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
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
                      Text(
                        p['content'] ?? '',
                        style: TextStyle(fontSize: 15, color: textColor, height: 1.3),
                      ),
                      if (p['media_blob'] != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(p['media_blob'] as Uint8List, fit: BoxFit.cover, width: 200, height: 150),
                        ),
                      ] else if (p['media'] != null && p['media'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildNetworkOrFile(p['media'].toString()),
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
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _toggleLike(p),
                        child: Row(
                          children: [
                            Icon(
                              p['isLiked'] == true ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: p['isLiked'] == true ? Colors.redAccent : (isDark ? Colors.white38 : Colors.grey.shade400),
                            ),
                            const SizedBox(width: 4),
                            Text('${p['likes'] ?? 0}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _replyToPost(p),
                        child: Row(
                          children: [
                            Icon(Icons.mode_comment_outlined, size: 14, color: isDark ? Colors.white38 : Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text('回覆', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
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

  Widget _buildNetworkOrFile(String src) {
    if (src.startsWith('data:image')) {
      return Image.memory(
          base64Decode(src.split(',').last),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 160);
    } else if (src.startsWith('http') || kIsWeb) {
      return Image.network(src,
          fit: BoxFit.cover, width: double.infinity, height: 160);
    } else {
      return Image.file(File(src),
          fit: BoxFit.cover, width: double.infinity, height: 160);
    }
  }

  // ── 成員 Tab ────────────────────────────────────────────────────
  Widget _buildMembersTab(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final active = _members
        .where((m) => m['status'] == 'active')
        .toList();
    final pending = _members
        .where((m) => m['status'] == 'pending')
        .toList();

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
          padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF8D6E63).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> m, bool isDark) {
    final name = m['display_name'] as String? ?? '未知用戶';
    final role = m['role'] as String? ?? 'member';
    final targetUserId = m['user_id'].toString();
    final bool canKick = _isOwnerOrAdmin &&
        role != 'owner' &&
        targetUserId != _currentUserId;
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
    final cardBg = isDark
        ? Colors.orange.withValues(alpha: 0.08)
        : Colors.orange.shade50;

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
                    style:
                        TextStyle(fontSize: 11, color: Colors.orange)),
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
                icon: const Icon(Icons.cancel,
                    color: Colors.redAccent, size: 26),
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
          color: const Color(0xFF8D6E63).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('⚙️ 管理員',
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFF8D6E63),
                fontWeight: FontWeight.bold)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildJoinButton() {
    return FloatingActionButton.extended(
      heroTag: 'group_join_fab',
      onPressed: _isJoining ? null : _joinOrApply,
      backgroundColor:
          _requiresApproval ? const Color(0xFFFF9800) : const Color(0xFF8D6E63),
      icon: _isJoining
          ? const SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Icon(_requiresApproval ? Icons.lock_open_rounded : Icons.group_add_rounded,
              color: Colors.white),
      label: Text(
        _requiresApproval ? '申請加入' : '加入群組',
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
