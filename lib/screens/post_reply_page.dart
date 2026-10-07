import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../database/database_helper.dart';
import '../widgets/common_widgets.dart';
import 'notes_screen.dart';
import '../services/app_locale_service.dart';

const Map<String, String> _kPostTypeLabel = {
  'note': '📝 學習筆記',
  'mood': '💭 心情文章',
  'doc': '📄 分享資料',
};

class PostReplyPage extends StatefulWidget {
  final Map<String, dynamic> originalPost;
  final Map<String, dynamic> currentUser;
  final String? autoTypeMessage;
  final int? targetCommentId;
  final String? targetCommentName;
  final VoidCallback? onAutoTypeDone;

  const PostReplyPage({
    super.key,
    required this.originalPost,
    required this.currentUser,
    this.autoTypeMessage,
    this.targetCommentId,
    this.targetCommentName,
    this.onAutoTypeDone,
  });

  @override
  State<PostReplyPage> createState() => _PostReplyPageState();
}

class _PostReplyPageState extends State<PostReplyPage> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  int? _replyToId;
  String _replyToName = '';
  final Set<int> _expandedCommentIds = {};

  /// 留言排序方式: '所有留言'(ASC)、'由新到舊'(DESC)、'最相關'(依回覆數)
  String _commentSort = '所有留言';

  @override
  void initState() {
    super.initState();
    _loadComments();
    if (widget.targetCommentId != null) {
      _replyToId = widget.targetCommentId;
      _replyToName = widget.targetCommentName ?? '';
    }
    if (widget.autoTypeMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAutoTyping();
      });
    }
  }

  void _startAutoTyping() async {
    String msg = widget.autoTypeMessage!;
    for (int i = 0; i < msg.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _commentController.text = msg.substring(0, i + 1);
      });
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _submitComment();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('pr_agent_sent'))));
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.pop(context);
      if (widget.onAutoTypeDone != null) {
        widget.onAutoTypeDone!();
      }
    }
  }

  Future<void> _loadComments() async {
    final db = await DatabaseHelper.instance.database;
    final postId = int.tryParse(widget.originalPost['id'].toString()) ??
        widget.originalPost['id'];
    final data = await db.query('comments',
        where: 'post_id = ?', whereArgs: [postId], orderBy: 'created_at ASC');

    List<Map<String, dynamic>> loaded = [];
    for (var c in data) {
      final user =
          await db.query('users', where: 'id = ?', whereArgs: [c['user_id']]);
      final String name =
          user.isNotEmpty ? user.first['display_name'] as String : tr('common_unknown_user');
      // 載入留言者頭像資料
      final int avatarColor =
          user.isNotEmpty ? ((user.first['avatar_color'] as int?) ?? 0) : 0;
      final Uint8List? avatarBlob =
          user.isNotEmpty ? user.first['avatar_blob'] as Uint8List? : null;
      final int avatarSelected =
          user.isNotEmpty ? ((user.first['avatar_selected'] as int?) ?? 0) : 0;

      loaded.add({
        ...c,
        'userId': c['user_id'],
        'author': name,
        'authorAvatarColor': avatarColor,
        'authorAvatarBlob': avatarBlob,
        'authorAvatarSelected': avatarSelected,
        'time': formatRelativeTime(c['created_at'])
      });
    }

    setState(() => _comments = loaded);
  }

  void _submitComment() async {
    if (_commentController.text.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final userId = widget.currentUser['id'];

    final newId = await db.insert('comments', <String, Object?>{
      'post_id': widget.originalPost['id'],
      'user_id': userId,
      'text': _commentController.text,
      'parent_id': _replyToId ?? 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    if ((widget.currentUser['username'] ?? '') == '訪客') {
      (widget.currentUser['session_comment_ids'] as Set<int>?)?.add(newId);
    }

    if (_replyToId != null) {
      _expandedCommentIds.add(_replyToId!);
      try {
        final replyToComment = _comments
            .firstWhere((c) => int.tryParse(c['id'].toString()) == _replyToId);
        final pid = int.tryParse(replyToComment['parent_id'].toString()) ?? 0;
        if (pid != 0) {
          _expandedCommentIds.add(pid);
        }
      } catch (_) {}
    }

    _commentController.clear();
    setState(() {
      _replyToId = null;
      _replyToName = '';
    });
    _loadComments();
  }

  void _deleteComment(int commentId) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(tr('qd_delete_comment'), style: TextStyle(fontSize: 16)),
              content: Text(tr('pr_delete_msg')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child:
                        Text(tr('btn_cancel'), style: TextStyle(color: Colors.grey))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child:
                        Text(tr('common_delete'), style: TextStyle(color: Colors.red))),
              ],
            ));

    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('comments', where: 'id = ?', whereArgs: [commentId]);
      _loadComments();
    }
  }

  void _editComment(int commentId, String currentText) async {
    final editController = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(tr('pr_edit_comment'), style: TextStyle(fontSize: 16)),
              content: TextField(
                controller: editController,
                maxLines: null,
                decoration: InputDecoration(hintText: tr('pr_edit_hint')),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr('btn_cancel'), style: TextStyle(color: Colors.grey))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, editController.text),
                    child: Text(tr('btn_save'),
                        style:
                            TextStyle(color: Theme.of(context).primaryColor))),
              ],
            ));

    if (newText != null && newText.isNotEmpty && newText != currentText) {
      final db = await DatabaseHelper.instance.database;
      await db.update('comments', <String, Object?>{'text': newText},
          where: 'id = ?', whereArgs: [commentId]);
      _loadComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group comments by parent_id
    Map<int, List<Map<String, dynamic>>> rootComments = {};
    for (var c in _comments) {
      int pid = int.tryParse(c['parent_id'].toString()) ?? 0;
      rootComments.putIfAbsent(pid, () => []).add(c);
    }

    // 將根留言依選定的排序方式排序
    List<Map<String, dynamic>> rootList = List.from(rootComments[0] ?? []);
    switch (_commentSort) {
      case '由新到舊':
        rootList.sort((a, b) {
          final ta =
              DateTime.tryParse(a['created_at'].toString()) ?? DateTime(0);
          final tb =
              DateTime.tryParse(b['created_at'].toString()) ?? DateTime(0);
          return tb.compareTo(ta);
        });
        break;
      case '最相關':
        rootList.sort((a, b) {
          final idA = int.tryParse(a['id'].toString()) ?? 0;
          final idB = int.tryParse(b['id'].toString()) ?? 0;
          final ra = rootComments[idA]?.length ?? 0;
          final rb = rootComments[idB]?.length ?? 0;
          return rb.compareTo(ra);
        });
        break;
      default:
        break;
    }

    // ── 顏色自適應（PostReplyPage 自行讀 Theme，不依賴 _isDarkMode）──
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F3F0);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor:
            (isDark ? Colors.black : Colors.white).withValues(alpha: 0.75),
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: textPrimary),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.transparent),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('pr_discussion'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary)),
            Text(tr('pr_comments_n', [_comments.length.toString()]),
                style: TextStyle(fontSize: 11, color: textSecondary)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── 留言列表 ──
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  // 原始貼文 header
                  _buildPostHeader(),
                  // 分隔線與留言計數
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: borderColor, height: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            tr('pr_comments_n', [_comments.length.toString()]),
                            style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(child: Divider(color: borderColor, height: 1)),
                      ],
                    ),
                  ),
                  // 留言排序選項
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        for (final label in ['所有留言', '由新到舊', '最相關'])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _commentSort = label),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _commentSort == label
                                      ? primaryColor
                                      : (isDark
                                          ? const Color(0xFF2A2A2A)
                                          : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _commentSort == label
                                        ? primaryColor
                                        : borderColor,
                                  ),
                                  boxShadow: _commentSort == label
                                      ? [
                                          BoxShadow(
                                            color: primaryColor.withValues(
                                                alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Text(trv(label),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _commentSort == label
                                            ? Colors.white
                                            : textSecondary,
                                        fontWeight: _commentSort == label
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 空狀態
                  if (_comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            ElasticIn(
                              key: ValueKey('empty_icon_$_commentSort'),
                              duration: const Duration(milliseconds: 700),
                              child: Icon(Icons.chat_bubble_outline_rounded,
                                  size: 56,
                                  color: primaryColor.withValues(alpha: 0.25)),
                            ),
                            const SizedBox(height: 14),
                            FadeInUp(
                              key: ValueKey('empty_text_$_commentSort'),
                              duration: const Duration(milliseconds: 400),
                              delay: const Duration(milliseconds: 300),
                              child: Text(tr('pr_empty'),
                                  style: TextStyle(
                                      color: textSecondary, fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 留言列表（staggered FadeIn）
                  ...rootList.asMap().entries.map((e) => FadeInUp(
                        key: ValueKey('${e.value['id']}_$_commentSort'),
                        duration: const Duration(milliseconds: 350),
                        delay: Duration(milliseconds: 50 * (e.key % 10)),
                        child: _buildCommentTree(e.value, rootComments),
                      )),
                ],
              ),
            ),

            // ── 正在回覆提示列 ──
            if (_replyToId != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.withValues(alpha: 0.12)
                      : const Color(0xFFFFF8F0),
                  border: Border(
                      top: BorderSide(
                          color: Colors.orange
                              .withValues(alpha: isDark ? 0.35 : 0.6),
                          width: 1.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr('pr_replying_to', [_replyToName.toString()]),
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyToId = null;
                        _replyToName = '';
                      }),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

            // ── 輸入區 ──
            if (widget.currentUser['id'] == 'u4')
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: Text(tr('pr_guest_no_comment'), style: TextStyle(color: textSecondary)),
              )
            else
              _ReplyInputBar(
                controller: _commentController,
                replyToName: _replyToId != null ? _replyToName : null,
                primaryColor: primaryColor,
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
                onSend: _submitComment,
                onCancelReply: _replyToId != null
                    ? () => setState(() {
                          _replyToId = null;
                          _replyToName = '';
                        })
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    final author = widget.originalPost['author'] ?? '?';
    final postType = widget.originalPost['postType'] as String?;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            buildAvatar(
                blob: widget.originalPost['authorAvatarBlob'] as Uint8List?,
                colorIdx: (widget.originalPost['authorAvatarColor'] as int?) ??
                    getAvatarColorIdx(author),
                initial: author.substring(0, 1),
                radius: 18,
                usePreset:
                    (widget.originalPost['authorAvatarSelected'] as int? ??
                                0) ==
                            1 &&
                        widget.originalPost['authorAvatarBlob'] == null),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(author,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87)),
                  Row(children: [
                    Text(widget.originalPost['time'],
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 11)),
                    if (postType != null &&
                        _kPostTypeLabel.containsKey(postType)) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF5F0EE),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(trv(_kPostTypeLabel[postType]!),
                            style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).primaryColor)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(widget.originalPost['content'],
              style: const TextStyle(
                  fontSize: 15, height: 1.5, color: Colors.black87)),
          if (widget.originalPost['media_blob'] != null ||
              (widget.originalPost['media'] != null &&
                  widget.originalPost['media'].toString().isNotEmpty)) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                Map<String, dynamic> attachedData = {};
                try {
                  final attached = widget.originalPost['attached_data'];
                  if (attached != null) {
                    if (attached is Map) {
                      attachedData = Map<String, dynamic>.from(attached);
                    } else if (attached is String && attached.isNotEmpty) {
                      attachedData =
                          jsonDecode(attached) as Map<String, dynamic>;
                    }
                  }
                } catch (_) {}
                final double alignX =
                    (attachedData['img_align_x'] as num?)?.toDouble() ?? 0.0;
                final double alignY =
                    (attachedData['img_align_y'] as num?)?.toDouble() ?? 0.0;
                final Alignment imgAlignment = Alignment(alignX, alignY);

                return Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: widget.originalPost['media_blob'] != null
                              ? Image.memory(
                                  widget.originalPost['media_blob']
                                      as Uint8List,
                                  fit: BoxFit.cover,
                                  alignment: imgAlignment)
                              : Image.network(
                                  widget.originalPost['media'] as String,
                                  fit: BoxFit.cover,
                                  alignment: imgAlignment),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          _buildPostAttachmentPreview(widget.originalPost),
        ],
      ),
    );
  }

  Widget _buildPostAttachmentPreview(Map<String, dynamic> p) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // 解析 attached_data
    Map<String, dynamic>? attached;
    final rawAttached = p['attached_data'];
    if (rawAttached is Map) {
      attached = Map<String, dynamic>.from(rawAttached);
    } else if (rawAttached is String && rawAttached.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAttached);
        if (decoded is Map) {
          attached = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    // 1. 檔案附件
    final fileName = (p['fileName'] ?? p['file_name'] ?? attached?['file_name'] ?? '').toString();
    if (fileName.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF26262B) : const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.insert_drive_file_rounded,
                  color: primaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('pr_shared_file'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. 學習 Pack
    if (p['postType'] == 'learning_pack' || (attached != null && attached.containsKey('pack_title'))) {
      if (attached != null) {
        final title = (attached['pack_title'] as String? ?? '').isNotEmpty
            ? attached['pack_title'].toString()
            : tr('pack_untitled');
        final desc = (attached['pack_description'] as String? ?? '').toString();

        final dynamic schedulesRaw = attached['schedules'];
        final dynamic quizzesRaw = attached['quizzes'];
        int schedCount = 0;
        int quizCount = 0;
        if (schedulesRaw is List) {
          schedCount = schedulesRaw.length;
        } else if (schedulesRaw is String && schedulesRaw.isNotEmpty) {
          try {
            schedCount = (jsonDecode(schedulesRaw) as List).length;
          } catch (_) {}
        }
        if (quizzesRaw is List) {
          quizCount = quizzesRaw.length;
        } else if (quizzesRaw is String && quizzesRaw.isNotEmpty) {
          try {
            quizCount = (jsonDecode(quizzesRaw) as List).length;
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.orange.withValues(alpha: 0.12)
                : const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.orange.withValues(alpha: 0.35)
                  : Colors.orange.shade200,
              width: 1.1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2_rounded,
                        color: Colors.orange.shade800, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tr('pack_label'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  desc,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? Colors.orange.shade200
                        : const Color(0xFF6B4512),
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (schedCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        tr('pr_sched_n', [schedCount.toString()]),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  if (quizCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        tr('pr_quiz_n', [quizCount.toString()]),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }
    }

    // 3. 筆記或題目 (Shared Resource)
    if (attached != null && attached['shared_type'] != null) {
      final sharedType = attached['shared_type'];

      if (sharedType == 'note') {
        final String title = attached['title'] ?? tr('note_untitled');
        final String category = attached['category'] ?? tr('val_uncategorized');
        final String rawContent = attached['content'] ?? '';
        final bool hasStrokes = attached['strokes'] != null &&
            attached['strokes'].toString() != '[]' &&
            attached['strokes'].toString().isNotEmpty;

        String cleanExcerpt = rawContent
            .replaceAll(RegExp(r'\[color=.*?\]'), '')
            .replaceAll('[/color]', '')
            .replaceAll(RegExp(r'#+\s*'), '')
            .replaceAll('**', '')
            .replaceAll('~~', '')
            .replaceAll('`', '')
            .replaceAll(RegExp(r'^[•\-\+\*]\s*', multiLine: true), '')
            .replaceAll(RegExp(r'\n+'), ' ')
            .trim();
        if (cleanExcerpt.isEmpty) {
          cleanExcerpt = tr('pr_tap_full');
        }

        return GestureDetector(
          onTap: () => _showNotePreviewDialog(p, attached!),
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF232328) : const Color(0xFFFAF8F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white12
                    : primaryColor.withValues(alpha: 0.2),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 左側質感主題色飾條
                    Container(
                      width: 4.5,
                      color: primaryColor,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 頂部列：圖示 + 標題 + 分類標籤
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    color: primaryColor,
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF2C2421),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : primaryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    category.startsWith('#')
                                        ? category
                                        : '#$category',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white70
                                          : primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 筆記內容精簡摘要
                            Text(
                              cleanExcerpt,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF6B625E),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // 底部特徵標籤與精緻匯入按鈕
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hasStrokes
                                            ? Icons.draw_rounded
                                            : Icons.article_rounded,
                                        size: 12,
                                        color: isDark
                                            ? const Color(0xFFCE93D8)
                                            : const Color(0xFF7B1FA2),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        hasStrokes ? tr('pr_handwritten') : tr('note_plain'),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? const Color(0xFFCE93D8)
                                              : const Color(0xFF7B1FA2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: () => _importSharedNote(p, attached!),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 11, vertical: 5),
                                    decoration: BoxDecoration(
                                      color:
                                          primaryColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: primaryColor
                                            .withValues(alpha: 0.35),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.download_rounded,
                                          size: 13,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          tr('note_import'),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
        );
      } else if (sharedType == 'question') {
        final String text = (attached['text'] as String?) ?? '';
        final dynamic rawOptions = attached['options'];
        List<dynamic> options = [];
        if (rawOptions is List) {
          options = rawOptions;
        } else if (rawOptions is String && rawOptions.isNotEmpty) {
          try {
            options = jsonDecode(rawOptions) as List<dynamic>;
          } catch (_) {}
        }
        final String subject = (attached['subject'] ?? '一般').toString();
        final String difficulty = (attached['difficulty'] ?? '中').toString();

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white10 : primaryColor.withValues(alpha: 0.2),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      color: primaryColor, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr('q_challenge', [subject.toString()]),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: primaryColor),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tr('q_difficulty', [difficulty.toString()]),
                      style: TextStyle(
                          fontSize: 10,
                          color: primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  text,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87),
                ),
              ],
              if (options.isNotEmpty) ...[
                const SizedBox(height: 10),
                Column(
                  children: List.generate(options.length, (idx) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF333333) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        '${String.fromCharCode(65 + idx)}. ${options[idx]}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }

  void _importSharedNote(Map<String, dynamic> p, Map<String, dynamic> attached) {
    try {
      final String title = attached['title'] ?? tr('note_untitled');
      final String content = attached['content'] ?? '';
      final String category = attached['category'] ?? '學習';
      final String authorName = p['author'] ?? tr('common_unknown_user');
      final String authorUserId = p['userId']?.toString() ?? '';
      final int authorAvatarColor = p['authorAvatarColor'] as int? ?? 0;

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

      final newNote = Note(
        id: 'note_${DateTime.now().millisecondsSinceEpoch}',
        userId: widget.currentUser['id']?.toString() ?? 'u1',
        title: '$title (社群匯入)',
        content: content,
        category:
            NotesDatabase.categories.contains(category) ? category : '未分類',
        strokes: strokes,
        updatedAt: DateTime.now(),
        authorName: authorName,
        authorUserId: authorUserId,
        authorAvatarColor: authorAvatarColor,
      );

      NotesDatabase.notes.insert(0, newNote);

      if (mounted) {
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
            content: Text(tr('note_imported')),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
            content: Text(tr('common_import_failed', [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNotePreviewDialog(
      Map<String, dynamic> p, Map<String, dynamic> attached) {
    final String rawTitle = attached['title'] as String? ?? '';
    final String rawContent = attached['content'] as String? ?? '';
    final String title = rawTitle.isNotEmpty ? rawTitle : tr('note_untitled');
    final String content = rawContent.isNotEmpty ? rawContent : (p['content'] as String? ?? '');
    final String category = (attached['category'] as String? ?? '').isNotEmpty
        ? (attached['category'] as String)
        : '學習';
    final String authorName = p['author'] as String? ?? tr('common_unknown_user');
    final String timeStr = p['time'] as String? ??
        (p['created_at']?.toString().split('T').first ?? '');

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.menu_book_rounded,
                    color: primaryColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$category',
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
              minWidth: double.maxFinite,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tr('pr_author', [authorName.toString()]),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· $timeStr',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    content,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.6,
                      color: isDark ? Colors.white70 : const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('btn_close'), style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _importSharedNote(p, attached);
              },
              icon: const Icon(Icons.download_rounded, size: 15),
              label: Text(tr('note_import')),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentTree(
      Map<String, dynamic> comment, Map<int, List<Map<String, dynamic>>> group,
      {int depth = 0}) {
    final int commentId = int.tryParse(comment['id'].toString()) ?? 0;
    List<Map<String, dynamic>> sub = group[commentId] ?? [];

    bool isExpanded =
        (sub.length == 1) || _expandedCommentIds.contains(commentId);
    final double leftPadding = depth < 3 ? 32.0 : 0.0;
    final double lineMargin = depth < 3 ? 14.0 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSingleComment(comment, isSub: depth > 0),
        if (sub.isNotEmpty) ...[
          if (sub.length >= 2 && !isExpanded)
            Padding(
              padding:
                  EdgeInsets.only(left: leftPadding + 8.0, bottom: 8, top: 2),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _expandedCommentIds.add(commentId);
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.subdirectory_arrow_right_rounded,
                          size: 13,
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.8)),
                      const SizedBox(width: 6),
                      Text(
                        tr('pr_view_replies', [sub.length.toString()]),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: Theme.of(context).primaryColor),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: EdgeInsets.only(left: lineMargin),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade200, width: 1.5),
                  ),
                ),
                padding: const EdgeInsets.only(left: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...sub.map(
                        (sc) => _buildCommentTree(sc, group, depth: depth + 1)),
                    if (sub.length >= 2) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _expandedCommentIds.remove(commentId);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.keyboard_arrow_up_rounded,
                                  size: 14,
                                  color: Theme.of(context).primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                tr('pr_collapse_replies'),
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSingleComment(Map<String, dynamic> c, {bool isSub = false}) {
    final author = (c['author'] ?? '?') as String;
    final bool isOwn = c['userId'] == widget.currentUser['id'];
    final bool isGuest = (widget.currentUser['username'] ?? '') == '訪客';
    final bool canEdit = isOwn &&
        (!isGuest ||
            ((widget.currentUser['session_comment_ids'] as Set<int>?)
                    ?.contains(c['id']) ??
                false));

    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.grey.shade500;

    // 留言氣泡顏色
    final ownBubbleBg = isDark
        ? Colors.orange.withValues(alpha: 0.12)
        : const Color(0xFFFFF8F0);
    final ownBubbleBorder =
        isDark ? Colors.orange.withValues(alpha: 0.25) : Colors.orange.shade100;
    final otherBubbleBg =
        isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade50;
    final otherBubbleBorder = isDark ? Colors.white12 : Colors.grey.shade200;

    return Container(
      margin: EdgeInsets.only(bottom: isSub ? 8 : 12, top: isSub ? 2 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildAvatar(
              blob: c['authorAvatarBlob'] as Uint8List?,
              colorIdx:
                  (c['authorAvatarColor'] as int?) ?? getAvatarColorIdx(author),
              initial: author.substring(0, 1),
              radius: isSub ? 11 : 14,
              usePreset: (c['authorAvatarSelected'] as int? ?? 0) == 1 &&
                  c['authorAvatarBlob'] == null),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名稱 + 時間列
                Row(
                  children: [
                    Flexible(
                      child: Text(author,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSub ? 12 : 13,
                              color: textPrimary)),
                    ),
                    const SizedBox(width: 6),
                    Text(c['time'],
                        style: TextStyle(color: textSecondary, fontSize: 11)),
                    const Spacer(),
                    // 編輯/刪除（自己的留言）
                    if (canEdit) ...[
                      GestureDetector(
                        onTap: () => _editComment(c['id'], c['text']),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.edit_outlined,
                              size: 14, color: textSecondary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _deleteComment(c['id']),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.delete_outline,
                              size: 14,
                              color: Colors.redAccent.withValues(alpha: 0.7)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // 留言內容氣泡
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOwn ? ownBubbleBg : otherBubbleBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    border: Border.all(
                      color: isOwn ? ownBubbleBorder : otherBubbleBorder,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    c['text'],
                    style: TextStyle(
                        fontSize: isSub ? 12 : 13,
                        color: textPrimary,
                        height: 1.45),
                  ),
                ),
                // 回覆按鈕
                if (!isOwn || isGuest)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, left: 4),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _replyToId = c['id'];
                        _replyToName = author;
                      }),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.reply_rounded,
                              size: 13, color: primaryColor),
                          const SizedBox(width: 3),
                          Text(tr('qd_reply'),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 留言輸入列（聚焦動畫 + 暗色適配）────────────────────────────────────
class _ReplyInputBar extends StatefulWidget {
  final TextEditingController controller;
  final String? replyToName;
  final Color primaryColor;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final VoidCallback onSend;
  final VoidCallback? onCancelReply;

  const _ReplyInputBar({
    required this.controller,
    required this.replyToName,
    required this.primaryColor,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.onSend,
    this.onCancelReply,
  });

  @override
  State<_ReplyInputBar> createState() => _ReplyInputBarState();
}

class _ReplyInputBarState extends State<_ReplyInputBar> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focused != _focus.hasFocus) {
        setState(() => _focused = _focus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color fieldBg = widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey.shade50;
    final Color activeBorder =
        _focused ? widget.primaryColor : widget.borderColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: widget.cardColor,
        border: Border(top: BorderSide(color: widget.borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: activeBorder, width: _focused ? 1.5 : 1.0),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                maxLines: null,
                scrollPadding: const EdgeInsets.only(bottom: 200),
                style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: widget.replyToName != null
                      ? tr('pr_reply_hint', [widget.replyToName.toString()])
                      : tr('pr_input_hint'),
                  hintStyle: TextStyle(
                      color:
                          widget.isDark ? Colors.white38 : Colors.grey.shade400,
                      fontSize: 14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
