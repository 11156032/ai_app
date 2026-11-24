import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../services/app_locale_service.dart';
import '../utils/question_utils.dart';

class QuestionDiscussionPage extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final Map<String, dynamic> currentUser;
  final bool isBottomSheet;

  const QuestionDiscussionPage({
    super.key,
    required this.questionData,
    required this.currentUser,
    this.isBottomSheet = false,
  });

  /// 以底部抽屜彈窗（Modal Bottom Sheet）形式開啟討論串，與 AI 解析保持一致的交互體驗
  static Future<T?> showAsBottomSheet<T>(
    BuildContext context, {
    required Map<String, dynamic> questionData,
    required Map<String, dynamic> currentUser,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuestionDiscussionPage(
        questionData: questionData,
        currentUser: currentUser,
        isBottomSheet: true,
      ),
    );
  }

  @override
  State<QuestionDiscussionPage> createState() => _QuestionDiscussionPageState();
}

class _QuestionDiscussionPageState extends State<QuestionDiscussionPage> {
  final TextEditingController _commentCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _discussions = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isGeneratingAi = false;
  late bool _isQuestionExpanded;
  String? _replyToUser;
  int _replyToParentId = 0;
  bool _isReplyingToSubReply = false;

  @override
  void initState() {
    super.initState();
    // 預設精簡折疊題目卡片，點擊卡片才展開對照，最大化留言與討論空間
    _isQuestionExpanded = false;
    if (!widget.isBottomSheet) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _loadDiscussions();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  int get _questionId {
    return int.tryParse(widget.questionData['id']?.toString() ?? '0') ?? 0;
  }

  String get _currentUserId {
    return (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
  }

  String get _currentUserName {
    return (widget.currentUser['name'] ?? widget.currentUser['username'] ?? tr('qd_partner')).toString();
  }

  String? get _currentUserAvatar {
    return widget.currentUser['avatar']?.toString() ?? widget.currentUser['avatar_url']?.toString();
  }

  Future<void> _loadDiscussions() async {
    try {
      if (_questionId == 0) {
        setState(() => _isLoading = false);
        return;
      }

      var list = await DatabaseHelper.instance.getDiscussionsForQuestion(
        _questionId,
        currentUserId: _currentUserId,
      );

      // 自動清理歷史誤點產生的多餘重複 AI 助教留言
      final aiList = list.where((d) => (d['is_ai_response'] as int? ?? 0) == 1 || d['user_id'] == 'u_ai_tutor').toList();
      if (aiList.length > 1) {
        // 保留最新/第一筆，將多餘重複的 AI 留言從資料庫移除
        for (int i = 1; i < aiList.length; i++) {
          final dupId = int.tryParse(aiList[i]['id']?.toString() ?? '0');
          if (dupId != null && dupId > 0) {
            await DatabaseHelper.instance.deleteQuestionDiscussion(dupId);
          }
        }
        list = await DatabaseHelper.instance.getDiscussionsForQuestion(
          _questionId,
          currentUserId: _currentUserId,
        );
      }

      // If discussions are completely empty, let's auto-seed with 1 or 2 high quality sample discussions if needed
      if (list.isEmpty) {
        await _seedInitialDiscussionsIfNeeded();
        final reloaded = await DatabaseHelper.instance.getDiscussionsForQuestion(
          _questionId,
          currentUserId: _currentUserId,
        );
        if (!mounted) return;
        setState(() {
          _discussions = reloaded;
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _discussions = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入討論串錯誤: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seedInitialDiscussionsIfNeeded() async {
    final sub = widget.questionData['subject']?.toString() ?? '一般';
    final explanation = widget.questionData['explanation']?.toString() ?? '';

    // Sample peer question & peer answer
    await DatabaseHelper.instance.addQuestionDiscussion(
      questionId: _questionId,
      userId: 'u_peer1',
      userName: '李同學 (建國中學)',
      content: '這題如果遇到類似題型，建議大家先畫出輔助線或拆解核心觀念，會快很多！',
    );

    if (explanation.isNotEmpty) {
      await DatabaseHelper.instance.addQuestionDiscussion(
        questionId: _questionId,
        userId: 'u_ai_tutor',
        userName: tr('qd_ai_tutor_name'),
        content: '【觀念提示】\n針對本題《$sub》考點：$explanation\n做題時注意審題關鍵字，排除干擾選項即可迅速作答！',
        isAiResponse: 1,
      );
    } else {
      await DatabaseHelper.instance.addQuestionDiscussion(
        questionId: _questionId,
        userId: 'u_tutor',
        userName: '陳助教 (解題教練)',
        content: '這題主要檢驗基本定義與邏輯推演，大家複習時可以多留意關鍵名詞與計算步驟。',
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      // 僅在回覆子留言（樓中樓）時標註對象，直接回覆主留言時正文保持純淨不加 @
      String contentToSend = text;
      if (_isReplyingToSubReply && _replyToUser != null) {
        contentToSend = '$_replyToUser $text';
      }

      await DatabaseHelper.instance.addQuestionDiscussion(
        questionId: _questionId,
        userId: _currentUserId,
        userName: _currentUserName,
        avatarUrl: _currentUserAvatar,
        content: contentToSend,
        parentId: _replyToParentId,
      );

      _commentCtrl.clear();
      _replyToUser = null;
      _replyToParentId = 0;
      _isReplyingToSubReply = false;

      await _loadDiscussions();

      // Scroll to bottom smoothly
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('送出留言失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('qd_send_failed'))),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _requestAiTutorResponse() async {
    if (_isGeneratingAi) return;

    // 檢查是否已存在 AI 助教留言，避免重複點擊洗版
    final hasAi = _discussions.any((d) => (d['is_ai_response'] as int? ?? 0) == 1 || d['user_id'] == 'u_ai_tutor');
    if (hasAi) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('qd_ai_already_exists') != 'qd_ai_already_exists' ? tr('qd_ai_already_exists') : 'AI 助教已為本題留下解答囉！'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isGeneratingAi = true);

    try {
      final sub = widget.questionData['subject']?.toString() ?? '一般';
      final explanation = widget.questionData['explanation']?.toString() ?? '';

      // Generate intelligent AI tutor response
      await Future.delayed(const Duration(milliseconds: 800));

      final buffer = StringBuffer();
      buffer.writeln(tr('qd_ai_view'));
      buffer.writeln(tr('qd_ai_core_type', [sub.toString()]));
      if (explanation.isNotEmpty) {
        buffer.writeln(tr('qd_ai_core_idea', [explanation.toString()]));
      } else {
        buffer.writeln(tr('qd_ai_tip'));
      }
      buffer.writeln(tr('qd_ai_ask'));

      await DatabaseHelper.instance.addQuestionDiscussion(
        questionId: _questionId,
        userId: 'u_ai_tutor',
        userName: tr('qd_ai_tutor_name'),
        content: buffer.toString(),
        isAiResponse: 1,
      );

      await _loadDiscussions();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('AI 助教生成失敗: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  Future<void> _toggleLike(int discussionId) async {
    try {
      await DatabaseHelper.instance.toggleLikeQuestionDiscussion(discussionId, _currentUserId);
      await _loadDiscussions();
    } catch (e) {
      debugPrint('點讚失敗: $e');
    }
  }

  Future<void> _deleteComment(int discussionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tr('qd_delete_comment'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(tr('qd_delete_comment_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('btn_cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('common_delete'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteQuestionDiscussion(discussionId);
      // 同時清除以它為父級的子回覆
      try {
        final db = await DatabaseHelper.instance.database;
        final childReplies = await db.query('question_discussions', where: 'parent_id = ?', whereArgs: [discussionId]);
        for (final r in childReplies) {
          final rId = int.tryParse(r['id']?.toString() ?? '0');
          if (rId != null && rId > 0) {
            await DatabaseHelper.instance.deleteQuestionDiscussion(rId);
          }
        }
      } catch (e) {
        debugPrint('清除關聯子回覆失敗: $e');
      }
      await _loadDiscussions();
    }
  }

  /// 獲取所有頂層主留言（parent_id 為 0，或父留言已不存在的留言）
  List<Map<String, dynamic>> get _rootDiscussions {
    final allIds = _discussions.map((d) => int.tryParse(d['id']?.toString() ?? '0') ?? 0).toSet();
    return _discussions.where((d) {
      final parentId = int.tryParse(d['parent_id']?.toString() ?? '0') ?? 0;
      return parentId == 0 || !allIds.contains(parentId);
    }).toList();
  }

  /// 獲取指定主留言底下的所有子回覆
  List<Map<String, dynamic>> _getRepliesFor(int rootId) {
    return _discussions.where((d) {
      final parentId = int.tryParse(d['parent_id']?.toString() ?? '0') ?? 0;
      return parentId == rootId;
    }).toList();
  }

  List<String> _getOptions() => QuestionUtils.parseOptions(widget.questionData['options']);

  String _formatTime(dynamic rawTime) {
    if (rawTime == null) return '';
    try {
      final dt = DateTime.tryParse(rawTime.toString());
      if (dt == null) return rawTime.toString();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return tr('time_just_now');
      if (diff.inMinutes < 60) return tr('time_min_ago', [diff.inMinutes.toString()]);
      if (diff.inHours < 24) return tr('time_hour_ago', [diff.inHours.toString()]);
      if (diff.inDays < 7) return tr('time_day_ago', [diff.inDays.toString()]);
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Color _getDifficultyColor(String diff) => QuestionUtils.getDifficultyColor(diff);

  @override
  Widget build(BuildContext context) {
    final sub = widget.questionData['subject']?.toString() ?? '一般';
    final diff = widget.questionData['difficulty']?.toString() ?? '中';
    final diffColor = _getDifficultyColor(diff);
    final qText = widget.questionData['question']?.toString() ?? widget.questionData['text']?.toString() ?? '';
    final options = _getOptions();
    final ansIndex = int.tryParse((widget.questionData['answerIndex'] ?? widget.questionData['answer'] ?? 0).toString()) ?? 0;
    final explanation = widget.questionData['explanation']?.toString() ?? '';

    final contentWidget = Column(
      children: [
        if (widget.isBottomSheet) _buildSheetHeader(),
        // ── 1. 頂部題目概覽卡片（點擊卡片切換展開/收合） ──
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => setState(() => _isQuestionExpanded = !_isQuestionExpanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 一體成型精緻微膠囊（整合科目與難度指標，兼顧識別度與設計質感）
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sub,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 1,
                              height: 10,
                              color: const Color(0xFFCBD5E1),
                            ),
                            Container(
                              width: 5.5,
                              height: 5.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: diffColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr('pb_diff_n', [diff.toString()]),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: diffColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // 輕量微小箭頭提示可展開/收合
                      Icon(
                        _isQuestionExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 題目敘述
                  Text(
                    qText,
                    maxLines: _isQuestionExpanded ? 6 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isQuestionExpanded ? const Color(0xFF1E293B) : const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),

                  // 展開時顯示選項與解析
                  if (_isQuestionExpanded) ...[
                    const SizedBox(height: 8),
                    if (options.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: List.generate(options.length, (idx) {
                          final isCorrect = idx == ansIndex;
                          final char = String.fromCharCode(65 + idx);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isCorrect ? const Color(0xFF10B981) : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              '$char. ${options[idx]} ${isCorrect ? "✔" : ""}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isCorrect ? const Color(0xFF065F46) : const Color(0xFF475569),
                                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }),
                      ),
                    if (explanation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          tr('qd_explanation', [explanation.toString()]),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.3),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── 2. 討論區主體 ──
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    // 討論區頂部統計與 AI 助教按鈕
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.forum_rounded, size: 18, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 6),
                            Text(
                              tr('qd_count', [_discussions.length.toString()]),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        // 若尚未有 AI 解答，才顯示召喚 AI 按鈕，避免重複點擊洗版
                        if (!_discussions.any((d) => (d['is_ai_response'] as int? ?? 0) == 1 || d['user_id'] == 'u_ai_tutor'))
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _isGeneratingAi ? null : _requestAiTutorResponse,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _isGeneratingAi
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF7C3AED)),
                                        )
                                      : const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isGeneratingAi ? tr('qd_thinking') : tr('qd_summon_ai'),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 留言清單（僅展示頂層主留言，子回覆收納於主留言內）
                    if (_discussions.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              tr('qd_empty'),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('qd_empty_sub'),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._rootDiscussions.map((d) {
                        return _buildCommentCard(d);
                      }),
                  ],
                ),
        ),

        // ── 3. 底部發布留言列 ──
        _buildBottomInputBar(),
      ],
    );

    if (widget.isBottomSheet) {
      final size = MediaQuery.of(context).size;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(maxHeight: size.height * 0.88),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              resizeToAvoidBottomInset: false,
              body: SafeArea(
                top: false,
                child: contentWidget,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          tr('qp_discussion'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF334155)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: contentWidget,
    );
  }

  Widget _buildSheetHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Color(0xFF4F46E5),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tr('qp_discussion'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> d) {
    final id = int.tryParse(d['id']?.toString() ?? '0') ?? 0;
    final userName = d['user_name']?.toString() ?? tr('qd_partner');
    final content = d['content']?.toString() ?? '';
    final timeStr = _formatTime(d['created_at']);
    final isAi = (d['is_ai_response'] as int? ?? 0) == 1;
    final isOwner = d['user_id']?.toString() == _currentUserId;
    final likesCount = int.tryParse(d['likes_count']?.toString() ?? '0') ?? 0;
    final isLiked = d['is_liked'] == true;

    final replies = _getRepliesFor(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAi ? const Color(0xFFF5F3FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAi ? const Color(0xFFC4B5FD) : Colors.grey.shade200,
          width: isAi ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 留言者頭像與名稱列
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: isAi ? const Color(0xFF7C3AED) : const Color(0xFFEEF2FF),
                child: isAi
                    ? const Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white)
                    : Text(
                        userName.isNotEmpty ? userName[0] : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4F46E5)),
                      ),
              ),
              const SizedBox(width: 10),

              // Name & AI Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isAi ? const Color(0xFF6D28D9) : const Color(0xFF1E293B),
                          ),
                        ),
                        if (isAi) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tr('qd_ai_badge'),
                              style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              // 刪除按鈕（本人留言或 AI 助教解答皆可刪除）
              if (isOwner || isAi)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () => _deleteComment(id),
                  tooltip: tr('qd_delete_comment'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 留言內容
          Text(
            content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isAi ? const Color(0xFF3B0764) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),

          // 底部互動按鈕（點讚 / 回覆）
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 回覆按鈕
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _replyToUser = '@$userName';
                    _replyToParentId = id;
                    _isReplyingToSubReply = false; // 直接回覆主留言，正文不硬塞 @
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.reply_rounded, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(tr('qd_reply'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 點讚按鈕
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _toggleLike(id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 15,
                        color: isLiked ? Colors.redAccent : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        likesCount > 0 ? '$likesCount' : tr('qd_like'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                          color: isLiked ? Colors.redAccent : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── 子回覆樓層區塊（巢狀收納於本則主留言下方） ──
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isAi
                    ? const Color(0xFFEDE9FE).withValues(alpha: 0.6)
                    : const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_right_rounded,
                          size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        '${replies.length} 則回覆',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  ...replies.map((r) => _buildReplyItem(r, rootId: id)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyItem(Map<String, dynamic> r, {required int rootId}) {
    final id = int.tryParse(r['id']?.toString() ?? '0') ?? 0;
    final userName = r['user_name']?.toString() ?? tr('qd_partner');
    final content = r['content']?.toString() ?? '';
    final timeStr = _formatTime(r['created_at']);
    final isAi = (r['is_ai_response'] as int? ?? 0) == 1;
    final isOwner = r['user_id']?.toString() == _currentUserId;
    final likesCount = int.tryParse(r['likes_count']?.toString() ?? '0') ?? 0;
    final isLiked = r['is_liked'] == true;

    // 解析是否有回覆對象：若正文開頭是 @某某，將其提取至作者欄位顯示「王小明 ‣ 李小華」，正文保持純淨無雜質
    String cleanContent = content;
    String? replyTargetName;

    if (content.startsWith('@')) {
      final spaceIndex = content.indexOf(' ');
      if (spaceIndex != -1) {
        replyTargetName = content.substring(1, spaceIndex).trim();
        cleanContent = content.substring(spaceIndex).trim();
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isAi ? const Color(0xFF7C3AED) : const Color(0xFFEEF2FF),
                child: isAi
                    ? const Icon(Icons.smart_toy_rounded, size: 13, color: Colors.white)
                    : Text(
                        userName.isNotEmpty ? userName[0] : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF4F46E5)),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAi ? const Color(0xFF6D28D9) : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (replyTargetName != null && replyTargetName.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_right_rounded, size: 15, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 1),
                      Flexible(
                        child: Text(
                          replyTargetName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              if (isOwner || isAi)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onPressed: () => _deleteComment(id),
                  tooltip: tr('qd_delete_comment'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            cleanContent,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF334155),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 回覆子留言（仍隸屬於此 rootId 樓層，但標註對象）
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  setState(() {
                    _replyToUser = '@$userName';
                    _replyToParentId = rootId;
                    _isReplyingToSubReply = true;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.reply_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(tr('qd_reply'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 點讚
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _toggleLike(id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 13,
                        color: isLiked ? Colors.redAccent : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        likesCount > 0 ? '$likesCount' : tr('qd_like'),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                          color: isLiked ? Colors.redAccent : const Color(0xFF64748B),
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
    );
  }

  Widget _buildBottomInputBar() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = bottomInset > 0 ? 10.0 : (MediaQuery.of(context).padding.bottom + 10.0);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 回覆對象標籤
          if (_replyToUser != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('qd_reply_to', [_replyToUser.toString()]),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() {
                            _replyToUser = null;
                            _replyToParentId = 0;
                            _isReplyingToSubReply = false;
                          }),
                          child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF4F46E5)),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _commentCtrl,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: tr('qd_input_hint'),
                      hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _isSending ? null : _sendComment,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4F46E5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
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
